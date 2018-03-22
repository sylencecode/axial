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

      def update_user_list(new_user_list)
        if (!new_user_list.is_a?(Axnet::UserList))
          raise(AxnetError, "attempted to add an object of type other than Axnet::UserList: #{user_list.inspect}")
        end
        LOGGER.info("attempting userlist update...")
        @bot.user_list.reload(new_user_list)
        LOGGER.info("userlist updated successfully (#{@bot.user_list.count} users)")
      end
    end
  end
end
