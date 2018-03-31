require 'axial/irc_types/nick'

module Axial
  module Axnet
    class AssistanceResponse
      attr_reader :channel_name, :type, :response, :request_types

      def initialize(channel_name, type, response)
        @request_types = %i(op keyword invite full banned)

        if (!@request_types.include?(type))
          raise(AxnetError, "valid request types are: #{request_types.join(', ')}")
        else
          @type           = type
        end

        @channel_name     = channel_name
        @response         = response
      end
    end
  end
end
