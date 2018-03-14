require 'log.rb'
module Axial
  # parent class for new addons
  class Addon
    include Axial::Handlers::Logging
    attr_reader :listeners, :name, :version, :author
    attr_accessor :irc

    def initialize()
      @listeners = []
      @name = "unnamed"
      @author = "unknown author"
      @version = "unknown version"
      @irc = nil
    end

    def on_part(method)
      LOGGER.debug("Channel part will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :part, method: method)
    end

    def on_quit(method)
      LOGGER.debug("IRC quit will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :quit, method: method)
    end

    def on_channel(command, method)
      LOGGER.debug("Channel command '#{command}' will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :channel, command: command, method: method)
    end

    def on_join(method)
      LOGGER.debug("Channel join will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :join, method: method)
    end

    def before_reload()
      LOGGER.debug("#{self.class}: before_reload super invoked")
    end
  end
end
