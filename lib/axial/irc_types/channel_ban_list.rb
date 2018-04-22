require 'timeout'
require 'axial/irc_types/channel_ban'

module Axial
  module IRCTypes
    class ChannelBanList
      attr_writer :synced

      def initialize(channel)
        @channel  = channel
        @ban_list = []
        @synced   = false
        @monitor  = Monitor.new
      end

      def all_bans()
        return @ban_list.clone
      end

      def clear()
        @monitor.synchronize do
          @ban_list.clear
        end
      end

      def synced?()
        return @synced
      end

      def include?(mask)
        return @ban_list.select { |ban| ban.mask.casecmp(mask).zero? }.any?
      end

      def add(ban)
        if (include?(ban.mask))
          return
        end
        @monitor.synchronize do
          @ban_list.push(ban)
        end
      end

      def remove(ban)
        if (ban.is_a?(String))
          @monitor.synchronize do
            @ban_list.delete_if { |tmp_ban| tmp_ban.mask.casecmp(ban).zero? }
          end
        else
          @monitor.synchronize do
            @ban_list.delete_if { |tmp_ban| tmp_ban.mask.casecmp(ban.mask).zero? }
          end
        end
      end
    end
  end
end
