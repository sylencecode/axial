module Axial
  module Axnet
    class AssistanceResponse
      attr_reader :channel_name, :type, :response

      def initialize(channel_name, type, response)
        @channel_name     = channel_name
        @type             = type
        @response         = response
      end
    end
  end
end
