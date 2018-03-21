require 'axial/axnet/user_list'

class AxnetError < StandardError
end

module Axial
  module Axnet
    class AxnetMonitor
      def initialize(bot)
        @bot = bot
        @user_list_monitor = Monitor.new
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
