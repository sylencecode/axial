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

        @nick_flood_threshold     = 2
        @nick_flood_period        = 30

        @join_flood_threshold     = 2
        @join_flood_period        = 10

        @text_flood_threshold     = 2
        @text_flood_period        = 15

        @global_text_threshold    = 4
        @global_text_period       = 30

        @revolving_door_period    = 30

        @timer                    = nil
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

      def check_text_flood(channel, nick, text)
        if (nick.opped_on?(channel) || nick.voiced_on?(channel))
          return
        end
        possible_user = @bot.user_list.get_from_nick_object(nick)
        if (!possible_user.nil?)
          return
        end

        @global_text_counter.push(Time.now)
        if (@global_text_counter.count >= @global_text_threshold)
          channel.message("i'm gonna +m this bitch but i better remember to -m it")
        end

        if (!@text_flood_counter.has_key?(nick.uuid))
          @text_flood_counter[nick.uuid] = [ Time.now ]
        else
          @text_flood_counter[nick.uuid].push(Time.now)
          if (@text_flood_counter[nick.uuid].count >= @text_flood_threshold)
            ban_mask = MaskUtils.ensure_wildcard(nick.host)
            channel.message("text flood, gonna have to ban #{ban_mask} now")
          end
        end
      end

      def check_join_flood(channel, nick)
        possible_user = @bot.user_list.get_from_nick_object(nick)
        if (!possible_user.nil?)
          return
        end

        @revolving_doors[nick.uuid] = Time.now
        @recent_joins.push(Time.now)
        if (@recent_joins.count >= @join_flood_threshold)
          channel.message("don't make +i this mofo in case i forget to -i it")
        end
      end

      def check_revolving_door(channel, nick, reason)
        possible_user = @bot.user_list.get_from_nick_object(nick)
        if (!possible_user.nil?)
          return
        end

        if (@revolving_doors.has_key?(nick.uuid))
          ban_mask = MaskUtils.ensure_wildcard(nick.host)
          channel.message("revolving door, gonna have to ban #{ban_mask} now")
        end
      end

      def check_nick_flood(nick, old_nick_name)
        if (nick.opped_on?(channel) || nick.voiced_on?(channel))
          return
        end
        possible_user = @bot.user_list.get_from_nick_object(nick)
        if (!possible_user.nil?)
          return
        end

        if (!@nick_changes.has_key?(nick.uuid))
          @nick_changes[nick.uuid] = [ Time.now ]
        else
          @nick_changes[nick.uuid].push(Time.now)
          if (@nick_changes[nick.uuid].count >= @nick_flood_threshold)
            @server_interface.channel_list.all_channels.each do |channel|
              ban_mask = MaskUtils.ensure_wildcard(nick.host)
              channel.message("that's #{@nick_changes[nick.uuid].count} nicks from #{nick.name}, banning #{ban_mask}")
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
        @timer = @bot.timer.every_second(self, :reset_flood_counters)
      end


      def handle_ban_unban(channel, nick, mode)
              response_mode = IRCTypes::Mode.new
              response_mode.ban(ban.mask)
              channel.set_mode(response_mode)
              channel.kick(nick, ban.long_reason)
      end

      def stop_flood_reset_timer()
        LOGGER.debug("stopping flood reset timer")
        @bot.timer.delete(@timer)
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: stopping flood reset timer")
        stop_flood_reset_timer
      end
    end
  end
end
