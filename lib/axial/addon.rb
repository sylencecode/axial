class AddonError < StandardError
end

module Axial
  # parent class for new addons
  class Addon
    include Axial::Handlers::Logging
    attr_reader     :listeners, :name, :version, :author, :throttle_secs
    attr_accessor   :last

    def initialize(server_interface)
      @listeners = []
      @name             = 'unnamed addon'
      @author           = 'unknown author'
      @version          = 'uknown version'
      @throttle_secs    = 0
      @server_interface = server_interface
    end

    def throttle(seconds)
      @throttle_secs = seconds
      @last = Time.now - @throttle_secs
    end

    def on_nick_change(method)
      LOGGER.debug("Nick changes will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :nick_change, method: method)
    end

    def on_mode(*in_args)
      if (in_args.nil? || in_args.count < 2)
        raise(AddonError, "#{self.class}.on_mode called without at least one mode and a callback method")
      end
      args = in_args.flatten
      method = args.pop
      modes = args
      LOGGER.debug("Channel mode change (#{modes.join(', ')}) will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :mode, method: method, modes: modes)
    end

    def on_part(method)
      LOGGER.debug("Channel part will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :part, method: method)
    end

    def on_quit(method)
      LOGGER.debug("IRC quit will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :quit, method: method)
    end

    def on_channel_sync(method)
      LOGGER.debug("Channel sync will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :channel_sync, method: method)
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