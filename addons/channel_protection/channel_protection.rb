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

        load_binds
      end

      def load_binds()
        on_startup                  :start_ban_cleanup_timer
        on_reload                   :start_ban_cleanup_timer

        on_join                     :auto_op_voice
        on_join                     :auto_ban

        on_mode @prevent_modes,     :handle_prevent_modes
        on_mode @enforce_modes,     :handle_enforce_modes
        on_mode :deops,             :handle_deop
        on_mode :ops,               :handle_op
        on_mode :bans,              :protect_banned_users
        on_channel_sync             :perform_initial_scan

        on_user_list                :check_for_new_users
        on_ban_list                 :check_for_new_bans

        on_self_kick                :rejoin
        on_kick                     :handle_kick

        on_privmsg          'exec', :dcc_wrapper, :handle_exec
        on_dcc              'exec', :dcc_wrapper, :handle_exec
      end

      def handle_kick(channel, kicker_nick, kicked_nick, _reason)
        user = get_bot_or_user(kicker_nick)
        possible_user = get_bot_or_user(kicked_nick)
        if (bot_or_op?(possible_user))
          if (!bot_or_director?(user))
            channel.kick(kicker_nick, "don't do that.")
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def rejoin(channel, kicker_nick, reason)
        LOGGER.warn("kicked from #{channel.name} by #{kicker_nick.uhost}: #{reason}")
        timer.in_a_bit do
          if (!server.trying_to_join.key?(channel.name.downcase))
            server.trying_to_join[channel.name.downcase] = ''
          end
          server.join_channel(channel.name)
        end
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
        channel_list.all_channels.select(&:opped?).each do |channel|
          timer.in_a_bit do
            response_mode = IRCTypes::Mode.new(server.max_modes)
            channel.ban_list.all_bans.select { |tmp_ban| tmp_ban.set_at + @maximum_ban_time <= Time.now }.each do |ban|
              response_mode.unban(ban.mask)
            end

            channel.set_mode(response_mode)
          end
        end
      end

      def check_channel_bans(channel) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        if (!channel.opped?)
          return
        end

        response_mode = IRCTypes::Mode.new(server.max_modes)
        bans = []
        kicks = []
        channel_nicks = channel.nick_list.all_nicks.reject { |tmp_nick| tmp_nick == myself }

        ban_list.all_bans.each do |ban|
          channel_nicks.each do |subject_nick|
            if (ban.match_mask?(subject_nick.uhost))
              bans.push(ban.mask)
              kicks.push(nick: subject_nick, reason: ban.long_reason)
            end
          end
        end

        timer.in_a_tiny_bit do
          response_mode = IRCTypes::Mode.new(server.max_modes)
          bans.each do |ban_mask|
            if (!channel.ban_list.include?(ban_mask))
              response_mode.ban(ban_mask)
            end
          end
          if (channel.opped?)
            channel.set_mode(response_mode)
          end

          if (kicks.any?)
            kicks.each do |kick|
              if (channel.opped? && channel.nick_list.include?(kick[:nick]))
                channel.kick(kick[:nick], kick[:reason])
              end
            end
          end
        end
      end

      def check_channel_users(channel) # rubocop:disable Metrics/MethodLength,Metrics/PerceivedComplexity,Metrics/AbcSize
        if (!channel.opped?)
          return
        end

        voice_nicks = []
        op_nicks = []
        channel.nick_list.all_nicks.reject { |tmp_nick| tmp_nick == myself }.each do |subject_nick|
          possible_user = get_bot_or_user(subject_nick)
          if (!possible_user.nil?)
            if (bot_or_op?(possible_user))
              op_nicks.push(subject_nick)
            elsif (possible_user.role.friend?)
              voice_nicks.push(subject_nick)
            end
          end
        end

        timer.in_a_tiny_bit do
          response_mode = IRCTypes::Mode.new(server.max_modes)
          op_nicks.each do |op_nick|
            if (channel.nick_list.include?(op_nick) && !op_nick.opped_on?(channel))
              response_mode.op(op_nick.name)
            end
          end

          voice_nicks.each do |voice_nick|
            if (channel.nick_list.include?(voice_nick) && !voice_nick.voiced_on?(channel))
              response_mode.voice(voice_nick.name)
            end
          end
          if (channel.opped?)
            channel.set_mode(response_mode)
          end
        end
      end

      def protect_banned_users(channel, nick, mode) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        if (!channel.opped? || nick == myself)
          return
        end

        user                  = get_bot_or_user(nick)

        kicks                 = []
        protected_user_names  = []
        unbans                = []

        mode.bans.each do |ban_mask| # rubocop:disable Metrics/BlockLength
          ban_mask = ban_mask.strip
          possible_users = get_bots_or_users_overlap(ban_mask)

          if (myself.match_mask?(ban_mask))
            immediate_response_mode = IRCTypes::Mode.new(server.max_modes)
            immediate_response_mode.unban(ban_mask)
            if (!user.role.root?)
              immediate_response_mode.deop(nick)
            end
            if (channel.opped?)
              channel.set_mode(immediate_response_mode)
            end
          elsif (possible_users.any? || myself.match_mask?(ban_mask))
            possible_users.sort_by { |tmp_user| tmp_user.role.numeric }.reverse.each do |possible_user|
              # roles are sorted highest to lowest for this comparison loop
              if (user.role.root?)
                next
              end

              if (user.role > possible_user.role)
                next
              end

              # example: ops cannot ban other ops, but managers+ can
              protected_user_names.push(possible_user.pretty_name_with_color)
              if (!unbans.include?(ban_mask))
                unbans.push(ban_mask)
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

        timer.in_a_tiny_bit do
          response_mode = IRCTypes::Mode.new(server.max_modes)
          unbans.each do |ban_mask|
            if (channel.ban_list.include?(ban_mask))
              response_mode.unban(ban_mask)
            end
          end

          if (channel.opped?)
            channel.set_mode(response_mode)
          end

          if (kicks.any?)
            kicks.each do |kick|
              if (channel.opped? && channel.nick_list.include?(kick[:nick]))
                channel.kick(kick[:nick], kick[:reason])
              end
            end
          end
        end
      end

      def handle_op(channel, _nick, mode)
        if (mode.ops.select { |tmp_op| tmp_op.casecmp(myself.name).zero? }.empty? || !channel.opped?)
          return
        end

        perform_initial_scan(channel)
      end

      def perform_initial_scan(channel)
        if (!channel.opped?)
          return
        end

        timer.in_a_tiny_bit do
          check_channel_bans(channel)
          check_channel_users(channel)
        end

        timer.in_a_bit do
          set_enforced_modes(channel)
          unset_prevented_modes(channel)
        end
      end

      def handle_deop(channel, nick, mode) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        if (!channel.opped? || nick == myself || mode.deops.empty?)
          return
        end

        reop_nicks = []
        deop_nicks = []
        user = get_bot_or_user(nick)

        mode.deops.each do |deop|
          if (deop == myself.name)
            channel.opped = false
          else
            reop_nicks    = []
            deop_nicks    = []
            subject_nick  = channel.nick_list.get(deop)
            possible_user = get_bot_or_user(subject_nick)
            if (bot_or_op?(possible_user))
              if (!subject_nick.opped_on?(channel))
                reop_nicks.push(subject_nick)
              end

              if (!bot_or_director?(user))
                deop_nicks.push(subject_nick)
              end
            end
          end
        end

        timer.in_a_tiny_bit do
          reop_nicks.each do |reop_nick|
            if (channel.nick_list.include?(reop_nick) && !reop_nick.opped_on?(channel))
              response_mode.op(reop_nick.name)
            end
          end
          deop_nicks.each do |deop_nick|
            if (channel.nick_list.include?(deop_nick) && deop_nick.opped_on?(channel))
              response_mode.deop(deop_nick.name)
            end
          end
          if (channel.opped?)
            channel.set_mode(response_mode)
          end
        end
      end

      def handle_prevent_modes(channel, nick, _mode)
        if (nick == myself || bot_or_director?(get_bot_or_user(nick)))
          return
        end

        timer.in_a_tiny_bit do
          unset_prevented_modes(channel)
        end
      end

      def unset_prevented_modes(channel)
        if (!channel.opped?)
          return
        end

        response_mode = IRCTypes::Mode.new(server.max_modes)
        prevent_modes = @prevent_modes.select { |prevent_mode| channel.mode.channel_modes.include?(prevent_mode) }

        prevent_modes.each do |channel_mode|
          if (channel_mode == :keyword)
            response_mode.unset_keyword(channel.mode.keyword)
          elsif (channel_mode == :limit)
            response_mode.limit = 0
          else
            response_mode.public_send((channel_mode.to_s + '=').to_sym, false)
          end
        end

        channel.set_mode(response_mode)
      end

      def handle_enforce_modes(channel, nick, mode)
        if (nick == myself || bot_or_director?(get_bot_or_user(nick)))
          return
        end

        timer.in_a_tiny_bit do
          set_enforced_modes(channel)
        end
      end

      def set_enforced_modes(channel) # rubocop:disable Naming/AccessorMethodName
        if (!channel.opped?)
          return
        end

        response_mode = IRCTypes::Mode.new(server.max_modes)
        enforce_modes = @enforce_modes.reject { |enforce_mode| channel.mode.channel_modes.include?(enforce_mode) }
        enforce_modes.each do |channel_mode|
          response_mode.public_send((channel_mode.to_s + '=').to_sym, true)
        end

        channel.set_mode(response_mode)
      end

      def auto_op_voice(channel, nick) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        if (nick == myself)
          return
        end

        user = get_bot_or_user_mask(nick.uhost)
        if (user.nil?)
          return
        end

        if (user.role.op?)
          timer.in_a_bit do
            if (channel.opped? && channel.nick_list.include?(nick) && !nick.opped_on?(channel))
              channel.op(nick)
              LOGGER.info("auto-opped #{nick.uhost} in #{channel.name} (user: #{user.pretty_name})")
            end
          end
        elsif (user.role.friend?)
          timer.in_a_bit do
            if (channel.opped? && channel.nick_list.include?(nick) && !nick.voiced_on?(channel))
              channel.voice(nick)
              LOGGER.info("auto-voiced #{nick.uhost} in #{channel.name} (user: #{user.pretty_name})")
            end
          end
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def auto_ban(channel, nick) # rubocop:disable Metrics/AbcSize
        timer.in_a_tiny_bit do
          user = get_bot_or_user_mask(nick.uhost)
          if (!user&.role&.root?)
            ban_list.all_bans.each do |ban|
              if (!channel.opped? || !ban.match_mask?(nick.uhost) || channel.ban_list.include?(ban.mask))
                next
              end

              response_mode = IRCTypes::Mode.new(server.max_modes)
              response_mode.ban(ban.mask)
              channel.set_mode(response_mode)

              if (channel.nick_list.include?(nick))
                channel.kick(nick, ban.long_reason)
              end
            end
          end
        end
      rescue Exception => ex
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
        timer.get_from_callback_method(:cleanup_old_bans).each do |tmp_timer|
          LOGGER.debug("warning - removing errant ban cleanup timer #{tmp_timer.callback_method}")
          timer.delete(tmp_timer)
        end
        @ban_cleanup_timer = timer.every_minute(self, :cleanup_old_bans)
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: stopping RSS ingest before addons are reloaded")
        stop_ban_cleanup_timer
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}", __FILE__, __LINE__)
        end
      end
    end
  end
end
