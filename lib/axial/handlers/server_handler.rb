module Axial
  module Handlers
    class ServerHandler
      def initialize(bot)
        @bot = bot
      end

      def handle_server_notice(text)
        LOGGER.info("SERVER NOTICE: #{text}")
      end

      def handle_who_list_entry(nick, uhost, channel_name, mode)
        LOGGER.debug("|#{nick}|#{uhost}|#{channel_name}|#{mode}|")
      end

      def handle_who_list_end(channel_name)
        if (@bot.server.channel_list.has_key?(channel_name.downcase))
          channel = @bot.server.channel_list[channel_name.downcase]
        else
          raise(ChannelHandlerException, "No channel list entry found for #{channel_name}")
        end
        LOGGER.debug("done with #{channel.name}")
      end
    end
  end
end