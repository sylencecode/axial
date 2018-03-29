require 'securerandom'

module Axial
  module Axnet
    class Complaint
      attr_accessor :channel_name, :problem, :uhost, :type
      def initialize()
        # :deopped, :banned, :invite, :keyword, :limit
        type            = nil
        @channel_name   = ''
        @uhost          = ''
        @uuid           = SecureRandom.uuid
      end
    end
  end
end
