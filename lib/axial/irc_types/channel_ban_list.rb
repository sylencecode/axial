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
      end

      def all_bans()
        return @ban_list.clone
      end

      def clear()
        @ban_list.clear
      end

      def synced?()
        return @synced
      end

      def include?(mask)
        return @ban_list.select { |ban| ban.mask.casecmp(mask).zero? }.any?
      end

      def add(ban)
        if (!include?(ban.mask))
          @ban_list.push(ban)
        end
      end

      def remove(ban)
        if (ban.is_a?(String))
          @ban_list.delete_if { |tmp_ban| tmp_ban.mask.casecmp(ban).zero? }
        else
          @ban_list.delete_if { |tmp_ban| tmp_ban.mask.casecmp(ban.mask).zero? }
        end
      end
    end
  end
end
