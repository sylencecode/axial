module Axial
  module IRCTypes
    class Nick
      attr_accessor :name, :uhost, :ident
      def initialize(server_interface, name, ident, uhost)
        @server_interface = server_interface
        @name = name
        @uhost = uhost
        @ident = ident
      end

      def message(text)
        @server_interface.send_private_message(@name, text)
      end

      def self.from_uhost(server_interface, uhost)
        if (uhost =~ /^(\S+)!(\S+)@\S+$/)
          name, ident = Regexp.last_match.captures
          nick = new(server_interface, name, ident, uhost)
          return nick
        else
          raise(ArgumentError, "Invalid uhost provided to #{self.class}: #{uhost}")
        end
      end
    end
  end
end
