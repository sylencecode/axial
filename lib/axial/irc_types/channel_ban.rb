module Axial
  module IRCTypes
    class ChannelBan
      attr_reader :mask, :set_by, :set_at
      def initialize(mask, set_by, set_at)
        @mask     = mask
        @set_by   = set_by

        if (set_at.kind_of?(String))
          @set_at = Time.at(set_at.to_i)
        elsif (set_at.kind_of?(Integer))
          @set_at = Time.at(set_at)
        else
          @set_at = set_at
        end
      end
    end
  end
end
