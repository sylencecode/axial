module Axial
  class Nick
    attr_accessor :name, :uhost, :ident, :host
    def initialize(irc, name, ident, uhost)
      @irc = irc
      @name = name
      @uhost = uhost
      @ident = ident
      @host = uhost
    end

    def message(text)
      @irc.send_privmsg(@name, text)
    end

    def self.from_uhost(irc, uhost)
      if (uhost =~ /(\S+)!(\S+)@(\S+)/)
        name = Regexp.last_match[1]
        ident = Regexp.last_match[2]
        host = Regexp.last_match[3]
        uhost = uhost
        nick = new(irc, name, ident, uhost)
        return nick
      else
        raise(ArgumentError, "Invalid uhost provided to #{self.class}: #{uhost}")
      end
    end
  end
end
