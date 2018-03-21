class AxnetError < StandardError
end

module Axial
  module Axnet
    class AxnetMonitor
      # subscribe to axnet queued
      def initialize(bot)
        @bot = bot
        @user_list_monitor = Monitor.new
      end

      def update_user_list(user_list)
        if (!user.is_a?(Axnet::UserList))
          raise(AxnetError, "attempted to add an object of type other than Axnet::UserList: #{user_list.inspect}")
        end
        LOGGER.info("attempting userlist update...")
        @user_list_monitor.synchronize do
          @bot.user_list = user_list
        end
        LOGGER.info("userlist updated successfully")
      end
    end
  end
end
