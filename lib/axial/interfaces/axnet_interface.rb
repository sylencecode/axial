require 'axial/axnet/user_list'
require 'axial/consumers/raw_consumer'

class AxnetError < StandardError
end

module Axial
  module Interfaces
    class AxnetInterface
      attr_accessor :bot, :command_queue, :transmitter_method, :transmitter_object

      def initialize(bot)
        @bot                  = bot
        @transmitter_object   = nil
        @transmitter_method   = nil
        @command_queue        = Consumers::RawConsumer.new
      end

      def self.copy(bot, old_interface)
        new_interface                     = new
        new_interface.bot                 = bot
        new_interface.transmitter_object  = old_interface.transmitter_object
        new_interface.transmitter_method  = old_interface.transmitter_method
        new_interface.command_queue       = old_interface.command_queue
        return new_interface
      end

      def stop()
        LOGGER.debug("axnet interface command queue stopping")
        @command_queue.stop
      end

      def start()
        LOGGER.debug("axnet interface command queue starting")
        @command_queue.start
      end

      def register_queue_callback()
        @command_queue.register_callback(self, :transmit_to_axnet)
      end

      def register_transmitter(object, method)
        @transmitter_object = object
        @transmitter_method = method.to_sym
      end

      def transmit_to_axnet(text)
        if (@transmitter_object.respond_to?(@transmitter_method))
          @transmitter_object.public_send(@transmitter_method, text)
        else
          raise(AxnetError, "there are no valid axnet handlers registered")
        end
      end

      def clear_queue()
        @command_queue.clear
      end

      def send(text)
        @command_queue.send(text)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_user_list(new_user_list)
        if (!new_user_list.is_a?(Axnet::UserList))
          raise(AxnetError, "attempted to add an object of type other than Axnet::UserList: #{user_list.inspect}")
        end
        LOGGER.info("attempting userlist update...")
        @bot.user_list.reload(new_user_list)
        LOGGER.info("userlist updated successfully (#{@bot.user_list.count} users)")
        LOGGER.info("transmitting new userlist to axnet...")
        user_list_yaml = YAML.dump(@bot.user_list).gsub(/\n/, "\0")
        transmit_to_axnet('USERLIST_RESPONSE ' + user_list_yaml)
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end
    end
  end
end
