require 'axial/mask_utils'

module Axial
  module Axnet
    class Ban
      attr_reader :mask, :user_name, :reason, :set_at

      def initialize(in_mask, user, reason, set_at)
        @mask = MaskUtils.ensure_wildcard(in_mask)
        if (user.nil?)
          @user = 'someone'
        elsif (user.is_a?(Axnet::User))
          @user_name = user.pretty_name
        elsif (user.is_a?(String))
          @user_name = user
        else
          @user_name = 'someone'
        end

        @reason = (reason.nil?) ? 'banned.' : reason
        @set_at = (set_at.nil?) ? Time.now : set_at
      end

      def long_reason()
        return "banned #{@set_at.strftime('%Y-%m-%d')} by #{@user_name}: #{@reason}"
      end

      def masks_overlap?(in_mask)
        match = false
        if (MaskUtils.masks_overlap?(@mask, in_mask))
          match = true
        end
        return match
      end

      def match_mask?(in_mask)
        match = false
        if (MaskUtils.masks_match?(@mask, in_mask))
          match = true
        end
        return match
      end
    end
  end
end
