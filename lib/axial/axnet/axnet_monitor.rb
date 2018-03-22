require 'axial/axnet/user_list'

class AxnetError < StandardError
end

module Axial
  module Axnet
    class AxnetMonitor
      def initialize(bot)
        @bot = bot
        @user_list_monitor  = Monitor.new
        @axnet_interface    = nil
        @axnet_method       = nil
      end

      def register_sender(object, method)
        @axnet_interface    = object
        @axnet_method       = method.to_sym
      end

      def send(text)
        if (@axnet_interface.respond_to?(@axnet_method))
          @axnet_interface.public_send(@axnet_method, text)
        end
      end

      def update_user_list(user_list)
        @user_list_monitor.synchronize do
          if (!user_list.is_a?(Axnet::UserList))
            raise(AxnetError, "attempted to add an object of type other than Axnet::UserList: #{user_list.inspect}")
          end
          LOGGER.info("attempting userlist update...")
          @bot.user_list = user_list
          LOGGER.info("userlist updated successfully")
        end
      end
    end
  end
end
