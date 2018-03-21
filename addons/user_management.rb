require 'axial/addon'
require 'axial/models/user'
require 'axial/models/mask'
require 'axial/axnet/user'

module Axial
  module Addons
    class UserManagement < Axial::Addon
      def initialize(bot)
        super

        @name    = 'user management'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'
        @valid_roles = %w(director manager op friend)

        on_channel '?addmask',  :add_mask
        on_channel '?adduser',  :add_user
        on_channel '?getmasks', :get_masks
        on_channel '?setrole',  :set_role
        on_channel_sync         :handle_channel_sync
        on_startup              :populate_bot_user_list
      end

      def populate_bot_user_list()
        user_list = Axnet::UserList.new
        Models::User.each do |user_model|
          user = Axnet::User.from_model(user_model)
          user_list.add(user)
        end
        @bot.axnet_monitor.update_user_list(user_list)
      end

      def handle_channel_sync(channel)
        channel.nick_list.all_nicks.each do |nick|
          user_model = Models::User.get_from_nick_object(nick)
          if (!user_model.nil?)
#            channel.message("#{nick.name} is here and is user #{user_model.pretty_name}")
            # check for bans
          end
        end
      end

      def get_masks(channel, nick, command)
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

      def add_mask(channel, nick, command)
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
            channel.message("#{nick.name}: try ?addmask <nick> <mask>")
            return
          end

          subject_model = Models::User.get_from_nickname(subject_nickname)
          if (subject_model.nil?)
            channel.message("#{nick.name}: user '#{subject_nickname}' not found.")
            return
          end

          subject_mask = Axial::MaskUtils.ensure_wildcard(subject_mask)
          subject_models = Models::Mask.get_users_from_mask(subject_mask)
          if (subject_models.count > 0)
            channel.message("#{nick.name}: Mask '#{subject_mask}' conflicts with: #{subject_models.collect{|user| user.pretty_name}.join(', ')}")
            return
          end

          mask_model = Models::Mask.create(mask: subject_mask, user_id: subject_model.id)
          channel.message("#{nick.name}: Mask '#{subject_mask}' added to #{subject_model.pretty_name}.")
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def set_role(channel, nick, command)
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
          channel.message("#{nick.name}: User '#{subject_model.pretty_name}' has been assigned the role of #{subject_role}.")
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end

      def add_user(channel, nick, command)
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

          subject_mask = Axial::MaskUtils.ensure_wildcard(subject_mask)
          subject_models = Models::Mask.get_users_from_mask(subject_mask)
          if (subject_models.count > 0)
            channel.message("#{nick.name}: Mask '#{subject_mask}' conflicts with: #{subject_models.collect{|user| user.pretty_name}.join(', ')}")
            return
          end

          subject_model = Models::User.create_from_nickname_mask(subject_nickname, subject_mask)
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
