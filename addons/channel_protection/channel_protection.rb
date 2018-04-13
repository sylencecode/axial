require 'axial/addon'
require 'axial/mask_utils'
require 'axial/irc_types/nick'

module Axial
  module Addons
    class ChannelProtection < Axial::Addon
      def initialize(bot)
        super

        @name    = 'channel protection'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'

        # :bans, :unbans, :invite_only, :keyword, :limit, :moderated, :no_outside_messages, :ops, :deops, :secret, :topic_ops_only, :voices, :devoices
        @enforce_modes              = %i[ topic_ops_only no_outside_messages ]
        @prevent_modes              = %i[ invite_only limit keyword moderated ]
        @op_deop_modes              = %i[ ops deops ]

        @ban_cleanup_timer          = nil

        @maximum_ban_time           = 3600

        on_startup                  :start_ban_cleanup_timer
        on_reload                   :start_ban_cleanup_timer

        on_join                     :auto_op_voice
        on_join                     :auto_ban

        on_mode @prevent_modes,     :handle_prevent_modes
        on_mode @enforce_modes,     :handle_enforce_modes
        on_mode @op_deop_modes,     :handle_op_deop
        on_mode :bans,              :protect_banned_users

        on_user_list                :check_for_new_users
        on_ban_list                 :check_for_new_bans

        on_self_kick                :rejoin
        on_kick                     :handle_kick

        on_privmsg          'exec', :dcc_wrapper, :handle_exec
        on_dcc              'exec', :dcc_wrapper, :handle_exec
      end

      def handle_kick(channel, kicker_nick, kicked_nick, reason)
        user = get_bot_or_user(kicker_nick)
        possible_user = get_bot_or_user(kicked_nick)
        if (bot_or_op?(possible_user))
          if (!bot_or_director?(user))
            if (!kicker_nick.is_a?(IRCTypes::Server) && kicker_nick.opped_on?(channel))
              channel.deop(kicker_nick)
              channel.kick(kicker_nick, "don't do that.")
            end
          end
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def rejoin(channel, kicker_nick, reason)
        wait_a_sec
        if (!server.trying_to_join.key?(channel.name.downcase))
          server.trying_to_join[channel.name.downcase] = ''
        end
        server.join_channel(channel.name)
      end

      def check_for_new_users()
        channel_list.all_channels.each do |channel|
          check_channel_users(channel)
        end
      end

      def check_for_new_bans()
        channel_list.all_channels.each do |channel|
          check_channel_bans(channel)
        end
      end

      def cleanup_old_bans()
        channel_list.all_channels.each do |channel|
          if (channel.opped?)
            wait_a_sec
            response_mode = IRCTypes::Mode.new(server)
            bans_to_remove = channel.ban_list.all_bans.select { |ban| ban.set_at + @maximum_ban_time <= Time.now }
            bans_to_remove.each do |ban|
              response_mode.unban(ban.mask)
            end
            if (response_mode.any?)
              channel.set_mode(response_mode)
            end
          end
        end
      end

      def check_channel_bans(channel)
        if (!channel.opped?)
          return
        end

        response_mode = IRCTypes::Mode.new(server)
        kicks = []
        ban_list.all_bans.each do |ban|
          channel.nick_list.all_nicks.reject { |tmp_nick| tmp_nick == myself }.each do |subject_nick|
            if (ban.match_mask?(subject_nick.uhost))
              if (!response_mode.bans.include?(ban.mask))
                response_mode.ban(ban.mask)
              end
              kicks.push(nick: subject_nick, reason: ban.long_reason)
            end
          end
        end

        if (response_mode.any?)
          channel.set_mode(response_mode)
        end
        kicks.each do |kick|
          channel.kick(kick[:nick], kick[:reason])
        end
      end

      def check_channel_users(channel)
        if (!channel.opped?)
          return
        end

        wait_a_sec

        response_mode = IRCTypes::Mode.new(server)
        channel.nick_list.all_nicks.reject { |tmp_nick| tmp_nick == myself }.each do |subject_nick|
          possible_user = get_bot_or_user(subject_nick)
          if (!possible_user.nil?)
            if (bot_or_op?(possible_user))
              # op bots and ops
              if (!subject_nick.opped_on?(channel))
                response_mode.op(subject_nick.name)
              end
            elsif (possible_user.role.friend?)
              # voice friends
              if (!subject_nick.voiced_on?(channel))
                response_mode.voice(subject_nick.name)
              end
            end
          end
        end

        if (response_mode.any?)
          channel.set_mode(response_mode)
        end
      end

      def protect_banned_users(channel, nick, mode)
        if (!channel.opped? || nick == myself)
          return
        end

        user = get_bot_or_user(nick)
        response_mode = IRCTypes::Mode.new(server)

        kicks = []
        mode.bans.each do |ban_mask|
          mask = ban_mask.strip
          possible_users = get_bots_or_users_overlap(mask)
          if (myself.match_mask?(mask) || possible_users.any?)
            if (!bot_or_director?(user))
              if (possible_users.any?)
                protected_user_names = possible_users.uniq.collect { |user| user.name }
                channel.message("#{nick.name}: mask '#{ban_mask}' would potentially ban protected users: #{protected_user_names.join(', ')}")
              end
              response_mode.unban(mask)
              if (!nick.is_a?(IRCTypes::Server) && nick.opped_on?(channel))
                response_mode.deop(nick)
              end
            end
          else
            channel.nick_list.all_nicks.reject { |tmp_nick| tmp_nick == myself }.each do |subject_nick|
              if (MaskUtils.masks_match?(ban_mask, subject_nick.uhost))
                kicks.push(nick: subject_nick, reason: "banned by #{nick.name}")
              end
            end
          end
        end

        if (response_mode.any?)
          channel.set_mode(response_mode)
        end

        kicks.each do |kick|
          channel.kick(kick[:nick], kick[:reason])
        end
      end

      def handle_op_deop(channel, nick, mode)
        if (!channel.opped? || nick == myself)
          return
        end

        user = get_bot_or_user(nick)
        response_mode = IRCTypes::Mode.new(server)

        if (mode.ops.any?)
          mode.ops.each do |op|
            if (op == myself.name)
              channel.opped = true
              check_channel_bans(channel)
              check_channel_users(channel)
            else
              subject_nick = channel.nick_list.get(op)
              possible_user = get_bot_or_user(subject_nick)
              if (possible_user.nil? || !possible_user.role.op?)
                if (!bot_or_director?(user))
                  if (subject_nick.opped_on?(channel))
                    response_mode.deop(subject_nick)
                  end
                end
              end
            end
          end
        end

        if (mode.deops.any?)
          mode.deops.each do |deop|
            if (deop == myself.name)
              channel.opped = false
            else
              # re-op users and penalize offender unless deopped by a director or bot
              subject_nick = channel.nick_list.get(deop)
              possible_user = get_bot_or_user(subject_nick)
              if (bot_or_op?(possible_user))
                if (!subject_nick.opped_on?(channel))
                  response_mode.op(subject_nick.name)
                end

                if (!bot_or_director?(user))
                  if (!nick.is_a?(IRCTypes::Server) && nick.opped_on?(channel))
                    response_mode.deop(nick)
                  end
                end
              end
            end
          end
        end

        if (response_mode.any?)
          channel.set_mode(response_mode)
        end
      end

      def handle_prevent_modes(channel, nick, mode)
        if (!channel.opped? || nick == myself)
          return
        end

        user = get_bot_or_user(nick)
        if (bot_or_director?(user))
          return
        end

        response_mode = IRCTypes::Mode.new(server)
        mode.channel_modes.each do |channel_mode|
          mode_set = mode.public_send((channel_mode.to_s + '?').to_sym)
          if (mode_set)
            if (channel_mode == :keyword)
              response_mode.unset_keyword(mode.keyword)
            elsif (channel_mode == :limit)
              response_mode.limit = 0
            else
              response_mode.public_send((channel_mode.to_s + '=').to_sym, false)
            end
          end
        end

        if (response_mode.any?)
          channel.set_mode(response_mode)
        end
      end

      def handle_enforce_modes(channel, nick, mode)
        if (!channel.opped? || nick == myself)
          return
        end

        user = get_bot_or_user(nick)
        if (bot_or_director?(user))
          return
        end

        response_mode = IRCTypes::Mode.new(server)
        mode.channel_modes.each do |channel_mode|
          mode_set = mode.public_send((channel_mode.to_s + '?').to_sym)
          if (!mode_set)
            response_mode.public_send((channel_mode.to_s + '=').to_sym, true)
          end
        end

        if (response_mode.any?)
          channel.set_mode(response_mode)
        end
      end

      def auto_op_voice(channel, nick)
        if (!channel.opped? || nick == myself)
          return
        end

        wait_a_sec
        user = get_bot_or_user_mask(nick.uhost)
        if (!user.nil?)
          if (user.role.op?)
            if (!nick.opped_on?(channel))
              channel.op(nick)
              LOGGER.info("auto-opped #{nick.uhost} in #{channel.name} (user: #{user.pretty_name})")
            end
          elsif (user.role.friend?)
            if (!nick.voiced_on?(channel))
              channel.voice(nick)
              LOGGER.info("auto-voiced #{nick.uhost} in #{channel.name} (user: #{user.pretty_name})")
            end
          end
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def auto_ban(channel, nick)
        if (!channel.opped? || nick == myself)
          return
        end

        user = get_bot_or_user_mask(nick.uhost)
        if (user.nil?)
          ban_list.all_bans.each do |ban|
            if (ban.match_mask?(nick.uhost))
              response_mode = IRCTypes::Mode.new(server)
              response_mode.ban(ban.mask)
              channel.set_mode(response_mode)
              channel.kick(nick, ban.long_reason)
            end
          end
        end
      rescue Exception => ex
        channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def handle_exec(source, user, nick, command)
        if (user.nil? || !user.role.director?)
          dcc_access_denied(source)
        elsif (command.args.empty?)
          reply(source, nick, "usage: #{command.command} <raw command>")
        else
          server.send_raw(command.args)
          LOGGER.info("#{nick.name} EXEC #{command.args.inspect}")
        end
      end

      def get_bot_or_user(nick)
        possible_user = user_list.get_from_nick_object(nick)
        if (possible_user.nil?)
          possible_user = bot_list.get_from_nick_object(nick)
        end
        return possible_user
      end

      def get_bot_or_user_mask(mask)
        possible_user = user_list.get_user_from_mask(mask)
        if (possible_user.nil?)
          possible_user = bot_list.get_user_from_mask(mask)
        end
        return possible_user
      end

      def get_bots_or_users_mask(mask)
        bots_or_users = []
        user_list.get_users_from_mask(mask).each do |tmp_mask|
          bots_or_users.push(tmp_mask)
        end
        bot_list.get_users_from_mask(mask).each do |tmp_mask|
          bots_or_users.push(tmp_mask)
        end
        return bots_or_users
      end

      def get_bots_or_users_overlap(mask)
        bots_or_users = []
        user_list.get_users_from_overlap(mask).each do |tmp_mask|
          bots_or_users.push(tmp_mask)
        end
        bot_list.get_users_from_overlap(mask).each do |tmp_mask|
          bots_or_users.push(tmp_mask)
        end
        return bots_or_users
      end

      def bot_or_director?(user)
        return (!user.nil? && (user.role.bot? || user.role.director?))
      end

      def bot_or_op?(user)
        return (!user.nil? && (user.role.bot? || user.role.op?))
      end

      def stop_ban_cleanup_timer()
        LOGGER.debug('stopping ban cleanup timer')
        timer.delete(@ban_cleanup_timer)
      end

      def start_ban_cleanup_timer()
        LOGGER.debug('starting ban cleanup timer')
        @ban_cleanup_timer = timer.every_minute(self, :cleanup_old_bans)
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: stopping RSS ingest before addons are reloaded")
        stop_ban_cleanup_timer
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}")
        end
      end
    end
  end
end