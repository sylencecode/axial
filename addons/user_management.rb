require 'models/user.rb'
require 'models/mask.rb'

module Axial
  module Addons
    class UserManagement < Axial::Addon
      def initialize()
        super

        @name    = 'user management'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_channel '?addmask',  :add_mask
        on_channel '?adduser',  :add_user
        on_channel '?getmasks', :get_masks
      end
      def get_masks(channel, nick, command)
        begin
          user_model = Models::User.get_from_nick_object(nick)
          if (user_model.nil?)
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
          if (user_model.nil?)
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

      def add_user(channel, nick, command)
        begin
          user_model = Models::User.get_from_nick_object(nick)
          if (user_model.nil?)
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
