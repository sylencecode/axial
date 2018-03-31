module Axial
  module Axnet
    class AssistanceRequest
      attr_reader :uhost, :channel_name, :type, :request_types

      def initialize(uhost, channel_name, type)
        @request_types = %i(op keyword invite full banned)

        if (!@request_types.include?(type))
          raise(AxnetError, "valid request types are: #{request_types.join(', ')}")
        else
          @type           = type
        end

        @uhost            = uhost
        @channel_name     = channel_name
      end
    end
  end
end
