module Axial
  # parent class for new addons
  class Addon
    include Axial::Handlers::Logging
    attr_reader     :listeners, :name, :version, :author
    attr_accessor   :server_interface

    def initialize()
      @listeners = []
      @name             = 'unnamed addon'
      @author           = 'unknown author'
      @version          = 'uknown version'
      @server_interface = nil
    end

    def on_part(method)
      LOGGER.debug("Channel part will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :part, method: method)
    end

    def on_quit(method)
      LOGGER.debug("IRC quit will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :quit, method: method)
    end

    def on_join(method)
      LOGGER.debug("Channel join will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :join, method: method)
    end

    def on_channel(command, method)
      if (command.is_a?(Regexp))
        LOGGER.debug("Channel text '#{command.source}' will invoke method '#{self.class}.#{method}'")
      else
        LOGGER.debug("Channel command '#{command}' will invoke method '#{self.class}.#{method}'")
      end
      @listeners.push(type: :channel, command: command, method: method)
    end

    def on_privmsg(command, method)
      LOGGER.debug("Private message '#{command}' will invoke method '#{self.class}.#{method}")
      @listeners.push(type: :privmsg, command: command, method: method)
    end

    def before_reload()
      LOGGER.debug("#{self.class}: before_reload super invoked")
    end
  end
end
