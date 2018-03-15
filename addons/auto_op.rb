require 'models/user.rb'
require 'models/mask.rb'

module Axial
  module Addons
    class AutoOp < Axial::Addon
      def initialize()
        super

        @name    = 'auto_op'
        @author  = 'sylence <sylence@sylence.org>'
        @version = '1.0.0'

        on_join    :auto_op
      end

      def auto_op(channel, nick)
        begin
          user = Models::Mask.get_user_from_mask(nick.uhost)
          if (!user.nil?)
            channel.op(nick)
            LOGGER.info("auto-opped #{nick.uhost} in #{channel.name} (user: #{user.pretty_name})")
          end
        rescue Exception => ex
          channel.message("#{self.class} error: #{ex.class}: #{ex.message}")
          LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
          ex.backtrace.each do |i|
            LOGGER.error(i)
          end
        end
      end
    end
  end
end
