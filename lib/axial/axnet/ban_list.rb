require 'axial/axnet/user'
require 'axial/mask_utils'

class BanListError < StandardError
end

module Axial
  module Axnet
    class BanList
      attr_reader :monitor

      def initialize()
        @ban_list = []
        @monitor = Monitor.new
      end

      def all_bans()
        return @ban_list.clone
      end

      def count()
        return @ban_list.count
      end

      def length()
        return @ban_list.count
      end

      def add(new_ban)
        if (!new_ban.is_a?(Axnet::Ban))
          raise(AxnetError, "attempted to add an object of type other than Axnet::Ban: #{ban_list.inspect}")
        end
        @monitor.synchronize do
          @ban_list.push(new_ban)
        end
      end

      def get_bans_from_mask(in_mask)
        bans = []
        @monitor.synchronize do
          left_mask = Axial::MaskUtils.ensure_wildcard(in_mask)
          left_regexp = Axial::MaskUtils.get_mask_regexp(in_mask)
          @ban_list.each do |right_ban|
            right_regexp = Axial::MaskUtils.get_mask_regexp(right_ban.mask)
            if (right_regexp.match(left_mask))
              bans.push(right_ban)
            elsif (left_regexp.match(right_ban.mask))
              bans.push(right_ban)
            end
          end
        end
        return bans
      end

      def reload(ban_list)
        if (!ban_list.is_a?(Axnet::BanList))
          raise(AxnetError, "attempted to add an object of type other than Axnet::BanList: #{ban_list.inspect}")
        end
        @monitor.synchronize do
          @ban_list.clear
          ban_list.all_bans.each do |ban|
            @ban_list.push(ban)
          end
        end
      end
    end
  end
end
