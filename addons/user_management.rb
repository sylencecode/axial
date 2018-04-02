require 'axial/addon'
require 'axial/models/user'
require 'axial/models/mask'
require 'axial/models/ban'

module Axial
  module Addons
    class UserManagement < Axial::Addon
      def initialize(bot)
        super

        @name    = 'user management'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'
        @valid_roles = %w(director manager op friend)

        on_channel   'addmask',   :dcc_channel_wrapper, :add_mask
        on_channel   'adduser',   :channel_wrap_add_user
        on_channel   'setrole',   :channel_wrap_set_role
        on_channel       'ban',   :channel_wrap_ban
        on_channel     'unban',   :channel_wrap_unban

        on_dcc       'addmask',   :dcc_channel_wrapper, :add_mask
        on_dcc       'adduser',   :dcc_wrap_add_user
        on_dcc       'setrole',   :dcc_wrap_set_role
        on_dcc           'ban',   :dcc_wrap_ban
        on_dcc         'unban',   :dcc_wrap_unban

        on_dcc          'bans',   :dcc_ban_list
        on_dcc         'whois',   :dcc_whois

        on_reload                 :update_user_list
        on_reload                 :update_ban_list
        on_startup                :update_user_list
        on_startup                :update_ban_list
      end

      def dcc_channel_wrapper(*args)
        source = args.shift
        if (source.is_a?(IRCTypes::Channel))
          nick = args.shift
          command = args.shift
          method = args.shift
          user = user_list.get_from_nick_object(nick)
        elsif (source.is_a?(IRCTypes::DCC))
          nick = IRCTypes::Nick.new(nil)
          nick.name = source.user.pretty_name
          command = args.shift
          method = args.shift
          user = source.user
        end
        self.send(method, source, user, nick, command)
      end

      def add_mask(source, user, nick, command)
        if (user.nil? || !user.manager?)
          return
        end

        source.message("hello #{nick.name}, you are a #{user.pretty_name} #{user.role} and that was #{command.inspect}")
      end

      def channel_wrap_add_mask(channel, nick, command)
        user = user_list.get_from_nick_object(nick)
        if (!user.nil? && !user.manager?)
          add_mask(channel, user, command)
        end
      end

      def dcc_wrap_add_mask(dcc, command)
        add_mask(dcc, dcc.user, command)
      end

      def dcc_ban_list(dcc, command)
        if (!dcc.user.op?)
          channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
          return
        end
      end
      
      def dcc_whois(dcc, command)
        dcc.message("who is #{command.args} indeed")
      end

      def dcc_wrap_ban(dcc, command)
        ban_mask(dcc, dcc.user, command)
      end

      def channel_wrap_ban(channel, nick, command)
        user = user_list.get_from_nick_object(nick)
        if (user.nil? || !user.op?)
          channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
        else
          ban_mask(channel, user, command)
        end
      end

      def dcc_unban(dcc, command)
        unban_mask(dcc, dcc.user, command)
      end

      def channel_unban(channel, nick, command)
        user = user_list.get_from_nick_object(nick)
        if (user.nil? || !user.op?)
          channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
        else
          unban_mask(channel, user, command)
        end
      end

      def ban_mask(sender, user, command)
        if (command.args.strip =~ /(\S+)(.*)/)
          mask, reason = Regexp.last_match.captures
        end

        if (mask.nil? || mask.strip.empty?)
          sender.message("try #{command.command} <mask> <reason>")
          return
        elsif (reason.nil? || reason.strip.empty?)
          reason = 'banned'
        end

        mask = MaskUtils.ensure_wildcard(mask.strip)
        reason = reason.strip

        begin
          bans = ban_list.get_bans_from_mask(mask)
          if (bans.count > 0)
            sender.message("mask '#{mask}' has already been banned by mask '#{bans.collect{ |ban| ban.mask }.join(', ')}'")
          else
            ban_model = Models::Ban.create(mask: mask, reason: reason, user_id: user.id, set_at: Time.now)
            update_ban_list
            sender.message("'#{ban_model.mask}' added to banlist.")
          end

          update_ban_list
        rescue Exception => ex
          sender.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def unban_mask(sender, user, command)
        if (command.args.strip =~ /(\S+)/)
          mask = Regexp.last_match[1]
        else
          sender.message("try #{command.command} <mask>")
          return
        end

        mask = MaskUtils.ensure_wildcard(mask)

        begin
          bans = ban_list.get_bans_from_mask(mask)
          if (bans.count == 0)
            sender.message("no bans matching '#{mask}'")
            return
          end

          bans.each do |ban|
            ban_model = Models::Ban[mask: ban.mask]
            if (!ban_model.nil?)
              ban_model.delete
              sender.message("'#{ban.mask}' removed from banlist.")
            else
              sender.message("'#{ban.mask}' isn't in the database?")
            end
          end

          update_ban_list
        rescue Exception => ex
          sender.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def update_user_list()
        new_user_list = Axnet::UserList.new
        Models::User.all.each do |user_model|
          user = Axnet::User.from_model(user_model)
          new_user_list.add(user)
        end
        axnet.update_user_list(new_user_list)
        axnet.broadcast_user_list
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_ban_list()
        new_ban_list = Axnet::BanList.new
        Models::Ban.all.each do |ban_model|
          ban = Axnet::Ban.new(ban_model.mask, ban_model.user.pretty_name, ban_model.reason, ban_model.set_at)
          new_ban_list.add(ban)
        end
        axnet.update_ban_list(new_ban_list)
        axnet.broadcast_ban_list
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def channel_get_masks(channel, nick, command)
        begin
          user_model = Models::User.get_from_nick_object(nick)
          if (user_model.nil? || !user_model.manager?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end
          if (command.args.strip =~ /(\S+)/)
            subject_nickname = Regexp.last_match[1]
          else
            channel.message("#{nick.name}: try ?getmasks <nick>")
            return
          end
          subject_model = Models::User.get_from_nickname(subject_nickname)
          if (subject_model.nil?)
            channel.message("#{nick.name}: user '#{subject_nickname}' not found.")
            return
          end
          channel.message("Current masks for #{subject_model.pretty_name}: #{subject_model.possible_masks.join(', ')}")
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def remove_mask(channel, nick, command)
        # needs to check if any other nicks have a mask and delete them
      end

      def channel_add_mask(sender, nick, command)
        begin
          if (command.args.strip =~ /(\S+)\s+(\S+)/)
            subject_nickname = Regexp.last_match[1]
            subject_mask = Regexp.last_match[2]
          else
            sender.message("try #{command.command} <nick> <mask>")
            return
          end

          subject_model = Models::User.get_from_nickname(subject_nickname)
          if (subject_model.nil?)
            sender.message("user '#{subject_nickname}' not found.")
            return
          end

          subject_mask = MaskUtils.ensure_wildcard(subject_mask)
          subject_models = Models::Mask.get_users_from_mask(subject_mask)
          if (subject_models.count > 0)
            sender.message("mask '#{subject_mask}' conflicts with: #{subject_models.collect{ |user| user.pretty_name }.join(', ')}")
            return
          end

          mask_model = Models::Mask.create(mask: subject_mask, user_id: subject_model.id)
          update_user_list
          sender.message("mask '#{subject_mask}' added to #{subject_model.pretty_name}.")
        rescue Exception => ex
          sender.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def channel_set_role(channel, nick, command)
        begin
          user_model = Models::User.get_from_nick_object(nick)
          if (user_model.nil? || !user_model.manager?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end

          if (command.args.strip =~ /(\S+)\s+(\S+)/)
            subject_nickname = Regexp.last_match[1]
            subject_role = Regexp.last_match[2].downcase
          else
            channel.message("#{nick.name}: try ?setrole <user> <#{@valid_roles.join('|')}>")
            return
          end

          if (!@valid_roles.include?(subject_role))
            channel.message("#{nick.name}: roles must be one of: #{@valid_roles.join(', ')}")
            return
          end

          subject_model = Models::User.get_from_nickname(subject_nickname)
          if (subject_model.nil?)
            channel.message("#{nick.name}: user '#{subject_nickname}' not found.")
            return
          end

          if (user_model.id == subject_model.id)
            channel.message("#{nick.name}: sorry, you can't modify yourself.")
            return
          end

          if (subject_role == 'manager' && !user_model.director?) 
            channel.message("#{nick.name}: sorry, only directors can assign new managers.")
            return
          end

          if (subject_role == 'director')
            if (!user_model.director? || user_model.id != 1) 
              channel.message("#{nick.name}: sorry, only #{Models::User[id: 1].pretty_name} can assign new directors.")
              return
            end
          end

          if (subject_model.director? && user_model.id != 1)
            channel.message("#{nick.name}: sorry, only #{Models::User[id: 1].pretty_name} can modify users who are directors.")
            return
          end

          subject_model.update(role: subject_role)
          update_user_list
          channel.message("#{nick.name}: User '#{subject_model.pretty_name}' has been assigned the role of #{subject_role}.")
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def channel_add_user(channel, nick, command)
        begin
          user_model = Models::User.get_from_nick_object(nick)
          if (user_model.nil? || !user_model.manager?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end
          if (command.args.strip =~ /(\S+)\s+(\S+)/)
            subject_nickname = Regexp.last_match[1]
            subject_mask = Regexp.last_match[2]
          else
            channel.message("#{nick.name}: try ?adduser <nick> <mask>")
            return
          end

          subject_model = Models::User.get_from_nickname(subject_nickname)
          if (!subject_model.nil?)
            channel.message("#{nick.name}: user #{subject_model.pretty_nick} already exists.")
            return
          end

          subject_mask = MaskUtils.ensure_wildcard(subject_mask)
          subject_models = Models::Mask.get_users_from_mask(subject_mask)
          if (subject_models.count > 0)
            channel.message("#{nick.name}: Mask '#{subject_mask}' conflicts with: #{subject_models.collect{ |user| user.pretty_name }.join(', ')}")
            return
          end

          subject_model = Models::User.create_from_nickname_mask(subject_nickname, subject_mask)
          update_user_list
          channel.message("#{nick.name}: User #{subject_model.pretty_name} created with mask '#{subject_mask}'.")
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end
    end
  end
end
