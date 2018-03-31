require 'axial/irc_types/nick'
require 'axial/mask_utils'
require 'axial/addon'

module Axial
  module Addons
    class FloodProtection < Axial::Addon
      def initialize(bot)
        super

        @name    = 'flood protection'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.1.0'

        @nick_flood_threshold     = 3
        @nick_flood_period        = 30

        @join_flood_threshold     = 3
        @join_flood_period        = 7

        @text_flood_threshold     = 5
        @text_flood_period        = 3

        @global_text_threshold    = 7
        @global_text_period       = 2

        @revolving_door_period    = 15

        @flood_reset_timer        = nil
        @nick_changes             = {} # not channel-specific, needs to ban on all channels
        @join_counter             = [] # needs to be channel-specific
        @text_flood_counter       = {} # needs to be channel-specific
        @revolving_doors          = {} # needs to be channel-specific
        @global_text_counter      = [] # needs to be channel-specific
        @recent_joins             = [] # needs to be channel-specific

        on_part                   :check_revolving_door
        on_join                   :check_join_flood
        on_channel_any            :check_text_flood
        on_nick_change            :check_nick_flood

        start_flood_reset_timer
      end

      def get_bot_or_user(nick)
        possible_user = user_list.get_from_nick_object(nick)
        if (possible_user.nil?)
          possible_user = bot_list.get_from_nick_object(nick)
        end
        return possible_user
      end

      def check_text_flood(channel, nick, text)
        if (!channel.opped?)
          return
        end

        possible_user = get_bot_or_user(nick)
        if (!possible_user.nil?)
          return
        end

        @global_text_counter.push(Time.now)
        if (@global_text_counter.count >= @global_text_threshold)
          if (!channel.mode.moderated? )
            response_mode = IRCTypes::Mode.new
            response_mode.moderated = true
            channel.set_mode(response_mode)

            timer.in_30_seconds do
              if (channel.opped?)
                if (channel.mode.moderated?)
                  response_mode = IRCTypes::Mode.new
                  response_mode.moderated = false
                  channel.set_mode(response_mode)
                end
              end
            end
          end
        end

        if (!@text_flood_counter.has_key?(nick.uuid))
          @text_flood_counter[nick.uuid] = [ Time.now ]
        else
          @text_flood_counter[nick.uuid].push(Time.now)
          if (@text_flood_counter[nick.uuid].count >= @text_flood_threshold)
            if (channel.opped?)
              ban_mask = MaskUtils.ensure_wildcard(nick.host)
              channel.ban(ban_mask)
              channel.kick(nick, "text flood: #{@text_flood_counter[nick.uuid].count} lines in #{@text_flood_period} seconds")
              timer.in_5_minutes do
                if (channel.opped?)
                  if (channel.ban_list.include?(ban_mask))
                    channel.unban(ban_mask)
                  end
                end
              end
            end
          end
        end
      end

      def check_join_flood(channel, nick)
        possible_user = get_bot_or_user(nick)
        if (!possible_user.nil?)
          return
        end

        @revolving_doors[nick.uuid] = Time.now
        @recent_joins.push(Time.now)
        if (@recent_joins.count >= @join_flood_threshold)
          if (channel.opped?)
            if (!channel.mode.invite_only?)
              response_mode = IRCTypes::Mode.new
              response_mode.invite_only = true
              channel.set_mode(response_mode)
              timer.in_1_minute do
                if (channel.opped?)
                  if (channel.mode.invite_only?)
                    response_mode = IRCTypes::Mode.new
                    response_mode.invite_only = false
                    channel.set_mode(response_mode)
                  end
                end
              end
            end
          end
        end
      end

      def check_revolving_door(channel, nick, reason)
        possible_user = get_bot_or_user(nick)
        if (!possible_user.nil?)
          return
        end

        if (channel.opped?)
          if (@revolving_doors.has_key?(nick.uuid))
            ban_mask = MaskUtils.ensure_wildcard(nick.host)
            channel.ban(ban_mask)
            timer.in_5_minutes do
              if (channel.ban_list.include?(ban_mask))
                channel.unban(ban_mask)
              end
            end
          end
        end
      end

      def check_nick_flood(nick, old_nick_name)
        possible_user = get_bot_or_user(nick)
        if (!possible_user.nil?)
          return
        end

        if (!@nick_changes.has_key?(nick.uuid))
          @nick_changes[nick.uuid] = [ Time.now ]
        else
          @nick_changes[nick.uuid].push(Time.now)
          if (@nick_changes[nick.uuid].count >= @nick_flood_threshold)
            server.channel_list.all_channels.each do |channel|
              if (channel.opped?)
                ban_mask = MaskUtils.ensure_wildcard(nick.host)
                channel.ban(ban_mask)
                channel.kick(nick, "nick flood: #{@nick_changes[nick.uuid].count} nick changes in #{@nick_flood_period} seconds")
                timer.in_5_minutes do
                  if (channel.opped?)
                    if (channel.ban_list.include?(ban_mask))
                      channel.unban(ban_mask)
                    end
                  end
                end
              end
            end
          end
        end
      end

      def reset_flood_counters()
        @nick_changes.values.each do |nick_change_times|
          nick_change_times.delete_if{ |time| time + @nick_flood_period <= Time.now }
        end

        # clear revovling doors
        @revolving_doors.delete_if{ |key, revolving_door_time| revolving_door_time + @revolving_door_period <= Time.now }

        # reset recent joins count for the channel
        @recent_joins.delete_if{ |join_time| join_time + @join_flood_period <= Time.now }

        # reset global text counters for the channel
        @global_text_counter.delete_if{ |text_time| text_time + @global_text_period <= Time.now }

        # reset text flood counters for each nick
        @text_flood_counter.values.each do |text_flood_times|
          text_flood_times.delete_if{ |time| time + @text_flood_period <= Time.now }
        end
      end

      def start_flood_reset_timer()
        LOGGER.debug("starting flood reset timer")
        @flood_reset_timer = timer.every_second(self, :reset_flood_counters)
      end

      def stop_flood_reset_timer()
        LOGGER.debug("stopping flood reset timer")
        timer.delete(@flood_reset_timer)
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: stopping flood reset timer")
        stop_flood_reset_timer
      end
    end
  end
end
