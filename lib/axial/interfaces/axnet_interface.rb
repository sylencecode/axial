require 'axial/axnet/user_list'
require 'axial/axnet/ban_list'
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
        @relay_object         = nil
        @relay_method         = nil
        @command_queue        = Consumers::RawConsumer.new
      end

      def self.copy(bot, old_interface)
        new_interface                     = new(bot)
        new_interface.transmitter_object  = old_interface.transmitter_object
        new_interface.transmitter_method  = old_interface.transmitter_method
        new_interface.command_queue       = old_interface.command_queue
        return new_interface
      end

      def stop()
        @command_queue.stop
      end

      def start()
        @command_queue.start
      end

      def register_queue_callback()
        @command_queue.register_callback(self, :transmit_to_axnet)
      end

      def register_transmitter(object, method)
        @transmitter_object = object
        @transmitter_method = method.to_sym
      end

      def register_relay(object, method)
        @relay_object = object
        @relay_method = method.to_sym
      end

      def relay_to_axnet(handler, text)
        if (@relay_object.nil? || @relay_method.nil?)
          return
        elsif (!@relay_object.respond_to?(@relay_method))
          raise(AxnetError, "there are no valid axnet relayers registered - #{@relay_object.class} does not respond to #{@relay_method}")
        else
          @relay_object.public_send(@relay_method, handler, text)
        end
      end

      def transmit_to_axnet(text)
        if (@transmitter_object.respond_to?(@transmitter_method))
          @transmitter_object.public_send(@transmitter_method, text)
        else
          raise(AxnetError, "there are no valid axnet transmitters registered")
        end
      end

      def clear_queue()
        @command_queue.clear
      end

      def broadcast_user_list()
        LOGGER.info("transmitting new userlist to axnet...")
        user_list_yaml = YAML.dump(@bot.user_list).gsub(/\n/, "\0")
        transmit_to_axnet('USERLIST_RESPONSE ' + user_list_yaml)
      end

      def broadcast_ban_list()
        LOGGER.info("transmitting new ban to axnet...")
        ban_list_yaml = YAML.dump(@bot.ban_list).gsub(/\n/, "\0")
        transmit_to_axnet('BANLIST_RESPONSE ' + ban_list_yaml)
      end

      def update_user_list(new_user_list)
        if (!new_user_list.is_a?(Axnet::UserList))
          raise(AxnetError, "attempted to add an object of type other than Axnet::UserList: #{user_list.inspect}")
        end
        LOGGER.info("attempting userlist update...")
        @bot.user_list.reload(new_user_list)
        LOGGER.info("userlist updated successfully (#{@bot.user_list.count} users)")
        @bot.bind_handler.dispatch_user_list_binds
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end

      def update_ban_list(new_ban_list)
        if (!new_ban_list.is_a?(Axnet::BanList))
          raise(AxnetError, "attempted to add an object of type other than Axnet::BanList: #{ban_list.inspect}")
        end
        LOGGER.info("attempting banlist update...")
        @bot.ban_list.reload(new_ban_list)
        LOGGER.info("banlist updated successfully (#{@bot.ban_list.count} bans)")
        @bot.bind_handler.dispatch_ban_list_binds
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end
    end
  end
end
