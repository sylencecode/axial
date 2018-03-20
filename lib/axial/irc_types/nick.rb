module Axial
  module IRCTypes
    class Nick
      attr_accessor :name, :ident, :host, :user_model, :voiced, :opped
      def initialize(server_interface)
        @server_interface = server_interface
        @name = ''
        @ident = ''
        @host = ''
        @user_model = nil
        @voiced = false
        @opped = false
      end

      def uhost()
        if (@name.empty? || @ident.empty? || @host.empty?)
          return ''
        else
          return "#{@name}!#{@ident}@#{@host}"
        end
      end

      def message(text)
        @server_interface.send_private_message(@name, text)
      end

      def ==(other_nick)
        puts "#{self.name} -> #{other_nick.name}"
        return (self.uhost == other_nick.uhost)
      end

      def self.from_uhost(server_interface, uhost)
        if (uhost =~ /^(\S+)!(\S+)@(\S+)$/)
          name, ident, host = Regexp.last_match.captures
          nick = new(server_interface)
          nick.name = name
          nick.ident = ident
          nick.host = host
          return nick
        else
          raise(ArgumentError, "Invalid uhost provided to #{self.class}: #{uhost}")
        end
      end
    end
  end
end
