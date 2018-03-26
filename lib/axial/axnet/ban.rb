require 'axial/mask_utils'

module Axial
  module Axnet
    class Ban
      attr_reader :mask, :user_name, :reason, :set_at
      def initialize(in_mask, user, reason, set_at)
        @mask = MaskUtils::ensure_wildcard(in_mask)
        if (user.nil?)
          @user = 'someone'
        elsif (user.is_a?(Axnet::User))
          @user_name = user.pretty_name
        elsif (user.is_a?(String))
          @user_name = user
        else
          @user_name = 'someone'
        end

        if (reason.nil?)
          @reason = 'banned.'
        else
          @reason = reason
        end

        if (set_at.nil?)
          @set_at = Time.now
        else
          @set_at = set_at
        end
      end

      def long_reason()
        return "banned #{@set_at.strftime("%m/%d/%Y")} by #{@user_name}: #{@reason}"
      end

      def match_mask?(in_mask)
        match_regexp = Axial::MaskUtils.get_mask_regexp(@mask)
        if (match_regexp.match(in_mask))
          return true
        else
          return false
        end
      end
    end
  end
end
