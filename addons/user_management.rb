#!/usr/bin/env ruby

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
          nick_model = Models::Nick.get_if_valid(nick)
          if (nick_model.nil?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end
          if (command.args.strip =~ /(\S+)/)
            user_nickname = Regexp.last_match[1]
          else
            channel.message("#{nick.name}: try ?getmasks <nick>")
            return
          end
          user_model = Models::Nick.get_from_nickname(user_nickname)
          if (user_model.nil?)
            channel.message("#{nick.name}: user '#{user_nickname}' not found.")
            return
          end
          channel.message("Current masks for #{user_model.pretty_nick}: #{user_model.possible_masks.join(', ')}")
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
          nick_model = Models::Nick.get_if_valid(nick)
          if (nick_model.nil?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end

          if (command.args.strip =~ /(\S+)\s+(\S+)/)
            user_nickname = Regexp.last_match[1]
            user_mask = Regexp.last_match[2]
          else
            channel.message("#{nick.name}: try ?addmask <nick> <mask>")
            return
          end

          user_model = Models::Nick.get_from_nickname(user_nickname)
          if (user_model.nil?)
            channel.message("#{nick.name}: user '#{user_nickname}' not found.")
            return
          end

          user_mask = Axial::MaskUtils.ensure_wildcard(user_mask)
          conflicting_nick = Models::Mask.get_nick_from_mask(user_mask)
          if (!conflicting_nick.nil?)
            channel.message("#{nick.name}: Mask '#{user_mask}' conflicts with #{conflicting_nick.nick}.")
            return
          end

          mask_model = Models::Mask.create(mask: user_mask, nick_id: user_model.id)
          channel.message("#{nick.name}: Mask '#{user_mask}' added to #{user_model.pretty_nick}.")
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
          nick_model = Models::Nick.get_if_valid(nick)
          if (nick_model.nil?)
            channel.message("#{nick.name}: #{Constants::ACCESS_DENIED}")
            return
          end
          if (command.args.strip =~ /(\S+)\s+(\S+)/)
            user_nickname = Regexp.last_match[1]
            user_mask = Regexp.last_match[2]
          else
            channel.message("#{nick.name}: try ?addmask <nick> <mask>")
            return
          end

          user_model = Models::Nick.get_from_nickname(user_nickname)
          if (!user_model.nil?)
            channel.message("#{nick.name}: user #{user_model.pretty_nick} already exists.")
            return
          end

          user_mask = Axial::MaskUtils.ensure_wildcard(user_mask)
          user_model = Models::Mask.get_nick_from_mask(user_mask)
          if (!user_model.nil?)
            channel.message("#{nick.name}: Mask '#{user_mask}' conflicts with user #{user_model.pretty_nick}.")
            return
          end

          user_model = Models::Nick.create_from_nickname_mask(user_nickname, user_mask)
          channel.message("#{nick.name}: User #{user_model.pretty_nick} created with mask '#{user_mask}'.")
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
