module Axial
  class Channel
    attr_reader :name
    def initialize(irc, name)
      @irc = irc
      @name = name
    end

    def op(nick)
      @irc.set_channel_mode(@name, "+o #{nick.name}")
    end

    def message(text)
      @irc.send_channel(@name, text)
    end
  end
end
