require 'axial/irc_types/mode'
require 'axial/irc_types/nick'
require 'axial/irc_types/channel_list'

class ServerInterfaceError < StandardError
end

module Axial
  class ServerInterface
    attr_reader     :channel_list
    attr_accessor   :myself

    def initialize(bot)
      @bot = bot
      @channel_list = IRCTypes::ChannelList.new(self)
      @myself = IRCTypes::Nick.new(self)
    end

    def join(channel_name, password)
      if (password.empty?)
        @bot.connection_handler.send_raw("JOIN #{channel_name}")
      else
        @bot.connection_handler.send_raw("JOIN #{channel_name} #{password}")
      end
    end

    # TODO: make a mode parser that checks server.modelimit or whatever
    def set_channel_mode(channel_name, mode)
      if (!mode.is_a?(IRCTypes::Mode))
        raise(ServerInterfaceError, "#{self.class}.set_channel_mode must be invoked with an Axial::IRCTypes::Mode object.")
      end
      mode.to_string_array.each do |mode_string|
        @bot.connection_handler.send_raw("MODE #{channel_name} #{mode_string}")
      end
    end

    def send_who(channel_name)
      @bot.connection_handler.send_raw("WHO #{channel_name}")
    end

    def set_topic(channel_name, text)
      @bot.connection_handler.send_raw("TOPIC #{channel_name} :#{text}")
    end

    def send_raw(raw)
      @bot.connection_handler.send_raw(raw)
    end

    def send_private_message(nick_name, text)
      puts "sending #{text.inspect}"
      @bot.connection_handler.send_chat("PRIVMSG #{nick_name} :#{text}")
    end

    def send_channel_message(channel_name, text)
      @bot.connection_handler.send_chat("PRIVMSG #{channel_name} :#{text}")
    end
  end
end
