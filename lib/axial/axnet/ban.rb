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
          @reason = reason
        else
          @reason = 'banned.'
        end

        if (set_at.nil?)
          @set_at = Time.now
        else
          @set_at = set_at
        end
      end
    end
  end
end
