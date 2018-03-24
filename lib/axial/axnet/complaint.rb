require 'securerandom'

module Axial
  module Axnet
    class Complaint
      attr_accessor :channel, :problem, :uhost
      def initialize()
        # :deopped, :banned, :invite, :keyword, :limit
        type            = nil
        @channel_name   = ''
        @uhost          = ''
        @id             = SecureRandom.uuid
      end
    end
  end
end
