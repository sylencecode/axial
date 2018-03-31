module Axial
  module Axnet
    class AssistanceRequest
      attr_reader :uhost, :channel_name, :type

      def initialize(uhost, channel_name, type)
        @uhost            = uhost
        @channel_name     = channel_name
        @type             = type
      end
    end
  end
end
