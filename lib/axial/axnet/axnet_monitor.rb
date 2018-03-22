require 'axial/axnet/user_list'

class AxnetError < StandardError
end

module Axial
  module Axnet
    class AxnetMonitor
      def initialize(bot)
        @bot             = bot
        @callback_object = nil
        @callback_method = nil
      end

      def register_callback(object, method)
        @callback_object = object
        @callback_method = method.to_sym
      end

      def send(text)
        if (@callback_object.respond_to?(@callback_method))
          @callback_object.public_send(@callback_method, text)
        end
      end

      def update_user_list(user_list)
        if (!user_list.is_a?(Axnet::UserList))
          raise(AxnetError, "attempted to add an object of type other than Axnet::UserList: #{user_list.inspect}")
        end
        LOGGER.info("attempting userlist update...")
        puts @bot.user_list.inspect
        @bot.user_list.reload(user_list)
        puts @bot.user_list.inspect
        LOGGER.info("userlist updated successfully")
      end
    end
  end
end
