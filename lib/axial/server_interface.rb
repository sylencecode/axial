module Axial
  class ServerInterface
    def initialize(bot)
      @bot = bot
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
      @bot.connection_handler.send_raw("MODE #{channel_name} #{mode}")
    end

    def send_who(channel_name)
      @bot.connection_handler.send_raw("WHO #{channel_name}")
    end

    def send_raw(raw)
      @bot.connection_handler.send_raw(raw)
    end

    def send_private_message(nick_name, text)
      @bot.connection_handler.send_chat("PRIVMSG #{nick_name} :#{text}")
    end

    def send_channel_message(channel_name, text)
      @bot.connection_handler.send_chat("PRIVMSG #{channel_name} :#{text}")
    end
  end
end