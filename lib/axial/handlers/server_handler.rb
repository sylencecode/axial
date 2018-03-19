module Axial
  module Handlers
    class ServerHandler
      def initialize(bot)
        @bot = bot
      end

      def handle_server_notice(text)
        LOGGER.info("SERVER NOTICE: #{text}")
      end
    end
  end
end
