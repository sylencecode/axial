module Axial
  module IRCTypes
    class Command
      attr_accessor :command, :args
      def initialize(command, args)
        @command = command
        @args = args
      end
    end
  end
end
