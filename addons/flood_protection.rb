require 'axial/irc_types/nick'
require 'axial/mask_utils'
require 'axial/addon'

module Axial
  module Addons
    class FloodProtection < Axial::Addon
      def initialize(bot)
        super

        @name                             = 'flood protection'
        @author                           = 'sylence <sylence@sylence.org>'
        @version                          = '1.1.0'

        flood_init

        flood_tolerance                   :nick_change,       limit: 2,   time: 3
        flood_tolerance                   :nick_change,       limit: 3,   time: 7
        flood_tolerance                   :nick_change,       limit: 4,   time: 20
        flood_tolerance                   :nick_change,       limit: 5,   time: 30

        flood_tolerance                   :channel_text,      limit: 5,   time: 5
        flood_tolerance                   :channel_text,      limit: 7,   time: 12
        flood_tolerance                   :channel_text,      limit: 10,  time: 17
        flood_tolerance                   :channel_text,      limit: 12,  time: 22
        flood_tolerance                   :channel_text,      limit: 15,  time: 30

        flood_tolerance                   :all_channel_text,  limit: 7,   time: 4
        flood_tolerance                   :all_channel_text,  limit: 10,  time: 7
        flood_tolerance                   :all_channel_text,  limit: 15,  time: 10

        flood_tolerance                   :revolving_door,                time: 30

        flood_tolerance                   :join,              limit: 3,   time: 2
        flood_tolerance                   :join,              limit: 5,   time: 7
        flood_tolerance                   :join,              limit: 7,   time: 15
        flood_tolerance                   :join,              limit: 10,  time: 30

        on_part                           :check_revolving_door
        on_join                           :check_join_flood
        on_channel_any                    :check_text_flood
        on_nick_change                    :check_nick_flood

        start_flood_reset_timer
      end

      def flood_init()
        @flood_reset_timer      = nil
        @flood_tracker          = {}
        @flood_limits           = {}
        @types                  = %i(all_channel_text channel_text join nick_change revolving_door)

        @types.each do |type|
          @flood_limits[type]   = []
          @flood_tracker[type]  = {}
        end
      end

      def flood_tolerance(flood_type, flood_hash)
        if (!@types.include?(flood_type))
          raise(AddonError, "#{self.class}: invalid flood type '#{flood_type}' provided.")
        end
        if (@flood_limits.nil?)
          @flood_limits = {}
        end
        if (!@flood_limits.key?(flood_type))
          @flood_limits[flood_type] = []
        end
        if (!@flood_limits.include?(flood_hash))
          @flood_limits[flood_type].push(flood_hash)
        end
      end

      def get_bot_or_user(nick)
        possible_user = user_list.get_from_nick_object(nick)
        if (possible_user.nil?)
          possible_user = bot_list.get_from_nick_object(nick)
        end
        return possible_user
      end

      def check_text_flood(channel, nick, text)
        possible_user = get_bot_or_user(nick)
        if (!possible_user.nil?)
          return
        end

        if (!@flood_tracker[:all_channel_text].key?(channel))
          @flood_tracker[:all_channel_text][channel] = {}
        end

        if (!@flood_tracker[:channel_text].key?(channel))
          @flood_tracker[:channel_text][channel] = {}
        end

        # check channel text
        if (@flood_limits.key?(:channel_text) && @flood_limits[:channel_text].any?)
          if (!@flood_tracker[:channel_text][channel].key?(nick.uuid))
            @flood_tracker[:channel_text][channel][nick.uuid] = [ Time.now ]
          else
            @flood_tracker[:channel_text][channel][nick.uuid].push(Time.now)
            @flood_limits[:channel_text].each do |flood_limit|
              message_count = @flood_tracker[:channel_text][channel][nick.uuid].select { |time| time >= Time.now - flood_limit[:time] }.count
              if (message_count >= flood_limit[:limit])
                if (channel.opped?)
                  ban_mask = MaskUtils.ensure_wildcard(nick.host)
                  channel.ban(ban_mask)
                  channel.kick(nick, "text flood: #{message_count} lines in #{flood_limit[:time]} seconds")
                  timer.in_5_minutes do
                    if (channel.opped?)
                      wait_a_sec
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

        if (@flood_limits.key?(:all_channel_text) && @flood_limits[:all_channel_text].any?)
          if (!@flood_tracker[:all_channel_text][channel].key?(nick.uuid))
            @flood_tracker[:all_channel_text][channel][nick.uuid] = [ Time.now ]
          else
            @flood_tracker[:all_channel_text][channel][nick.uuid].push(Time.now)
            @flood_limits[:all_channel_text].each do |flood_limit|
              message_count = @flood_tracker[:all_channel_text][channel][nick.uuid].select { |time| time >= Time.now - flood_limit[:time] }.count
              if (message_count >= flood_limit[:limit])
                if (channel.opped?)
                  if (!channel.mode.moderated?)
                    response_mode = IRCTypes::Mode.new(server)
                    response_mode.moderated = true
                    channel.set_mode(response_mode)

                    timer.in_30_seconds do
                      if (channel.opped?)
                        wait_a_sec
                        if (channel.mode.moderated?)
                          response_mode = IRCTypes::Mode.new(server)
                          response_mode.moderated = false
                          channel.set_mode(response_mode)
                        end
                      end
                    end
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

        if (@flood_limits[:revolving_door].any?)
          if (!@flood_tracker[:revolving_door].key?(channel))
            @flood_tracker[:revolving_door][channel] = {}
          end

          if (!@flood_tracker[:revolving_door][channel].key?(nick.uuid))
            @flood_tracker[:revolving_door][channel][nick.uuid] = [ Time.now ]
          else
            @flood_tracker[:revolving_door][channel][nick.uuid].push(Time.now)
          end
        end

        if (@flood_limits[:join].any?)
          if (!@flood_tracker[:join].key?(channel))
            @flood_tracker[:join][channel] = []
          end

          @flood_tracker[:join][channel].push(Time.now)

          @flood_limits[:join].each do |flood_limit|
            join_count = @flood_tracker[:join][channel].select { |join_time| join_time >= Time.now - flood_limit[:time] }.count
            if (join_count >= flood_limit[:limit])
              if (channel.opped?)
                if (!channel.mode.invite_only?)
                  response_mode = IRCTypes::Mode.new(server)
                  response_mode.invite_only = true
                  channel.set_mode(response_mode)

                  timer.in_30_seconds do
                    if (channel.opped?)
                      wait_a_sec
                      if (channel.mode.invite_only?)
                        response_mode = IRCTypes::Mode.new(server)
                        response_mode.invite_only = false
                        channel.set_mode(response_mode)
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      def check_revolving_door(channel, nick, reason)
        if (@flood_limits.key?(:revolving_door) && @flood_limits[:revolving_door].any?)
          flood_limit = @flood_limits[:revolving_door].first
          if (@flood_tracker[:revolving_door].key?(channel))
            if (@flood_tracker[:revolving_door][channel].key?(nick.uuid))
              revolving_door_count = @flood_tracker[:revolving_door][channel][nick.uuid].select { |time| time >= Time.now - flood_limit[:time] }.count
              if (revolving_door_count >= 1)
                if (channel.opped?)
                  ban_mask = MaskUtils.ensure_wildcard(nick.host)
                  channel.ban(ban_mask)
                  timer.in_5_minutes do
                    if (channel.opped?)
                      wait_a_sec
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
      end

      def check_nick_flood(nick, old_nick_name)
        possible_user = get_bot_or_user(nick)
        if (!possible_user.nil?)
          return
        end

        if (!@flood_tracker[:nick_change].key?(nick.uuid))
          @flood_tracker[:nick_change][nick.uuid] = []
        end

        if (@flood_limits.key?(:nick_change) && @flood_limits[:nick_change].any?)
          if (!@flood_tracker[:nick_change].key?(nick.uuid))
            @flood_tracker[:nick_change][nick.uuid] = [ Time.now ]
          else
            @flood_tracker[:nick_change][nick.uuid].push(Time.now)
            @flood_limits[:nick_change].each do |flood_limit|
              nick_change_count = @flood_tracker[:nick_change][nick.uuid].select { |time| time >= Time.now - flood_limit[:time] }.count
              if (nick_change_count >= flood_limit[:limit])
                channel_list.all_channels.each do |channel|
                  if (channel.opped?)
                    ban_mask = MaskUtils.ensure_wildcard(nick.host)
                    channel.ban(ban_mask)
                    channel.kick(nick, "nick flood: #{nick_change_count} nick changes in #{flood_limit[:time]} seconds")
                    timer.in_5_minutes do
                      if (channel.opped?)
                        wait_a_sec
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
        end
      end

      def reset_flood_counters()
        highest_text_limit = @flood_limits[:channel_text].collect { |tracker| tracker[:time] }.max
        @flood_tracker[:channel_text].values.each do |channel_entries|
          channel_entries.each do |uuid, line_array|
            line_array.delete_if { |line| line + highest_text_limit < Time.now }
            if (channel_entries[uuid].count.zero?)
              channel_entries.delete(uuid)
            end
          end
        end

        highest_all_text_limit = @flood_limits[:all_channel_text].collect { |tracker| tracker[:time] }.max
        @flood_tracker[:all_channel_text].values.each do |channel_entries|
          channel_entries.each do |uuid, line_array|
            line_array.delete_if { |line| line + highest_all_text_limit < Time.now }
            if (channel_entries[uuid].count.zero?)
              channel_entries.delete(uuid)
            end
          end
        end

        highest_nick_change_limit = @flood_limits[:nick_change].collect { |tracker| tracker[:time] }.max
        @flood_tracker[:nick_change].each do |uuid, line_array|
          line_array.delete_if { |line| line + highest_nick_change_limit < Time.now }
          if (@flood_tracker[:nick_change][uuid].count.zero?)
            @flood_tracker[:nick_change].delete(uuid)
          end
        end

        @flood_tracker[:revolving_door].values.each do |channel_entries|
          channel_entries.each do |uuid, line_array|
            line_array.delete_if { |part_time| part_time + @flood_limits[:revolving_door].first[:time] < Time.now }
            if (channel_entries[uuid].count.zero?)
              channel_entries.delete(uuid)
            end
          end
        end

        highest_join_limit = @flood_limits[:nick_change].collect { |tracker| tracker[:time] }.max
        @flood_tracker[:join].values.each do |channel_entries|
          channel_entries.delete_if { |join_time| join_time + highest_join_limit < Time.now }
        end
      end

      def start_flood_reset_timer()
        LOGGER.debug('starting flood reset timer')
        @flood_reset_timer = timer.every_second(self, :reset_flood_counters)
      end

      def stop_flood_reset_timer()
        LOGGER.debug('stopping flood reset timer')
        timer.delete(@flood_reset_timer)
      end

      def before_reload()
        super
        LOGGER.info("#{self.class}: stopping flood reset timer")
        stop_flood_reset_timer
        self.class.instance_methods(false).each do |method_symbol|
          LOGGER.debug("#{self.class}: removing instance method #{method_symbol}")
          instance_eval("undef #{method_symbol}")
        end
      end
    end
  end
end
