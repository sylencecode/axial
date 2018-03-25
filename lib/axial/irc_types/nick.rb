module Axial
  module IRCTypes
    class Nick
      attr_accessor :name, :ident, :host, :user_model
      def initialize(server_interface)
        @server_interface = server_interface
        @name = ''
        @ident = ''
        @host = ''
        @user_model = nil
        @voiced = false
        @opped = false
      end

      def opped=(value)
        @opped = value
      end

      def voiced=(value)
        @voiced = value
      end

      def opped?()
        return @opped
      end

      def voiced?()
        return @voiced
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
          return nil
        end
      end
    end
  end
end
