class AddonError < StandardError
end

module Axial
  # parent class for new addons
  class Addon
    attr_reader     :listeners, :name, :version, :author, :throttle_secs
    attr_accessor   :last

    def initialize(bot)
      @listeners = []
      @name             = 'unnamed addon'
      @author           = 'unknown author'
      @version          = 'uknown version'
      @throttle_secs    = 0
      @bot              = bot
    end

    def bind_handler()
      return @bot.bind_handler
    end

    def user_list()
      return @bot.user_list
    end

    def bot_list()
      return @bot.bot_list
    end

    def myself()
      return @bot.server_interface.myself
    end

    def ban_list()
      return @bot.ban_list
    end

    def axnet()
      return @bot.axnet
    end

    def channel_list()
      return @bot.server_interface.channel_list
    end

    def server()
      return @bot.server_interface
    end

    def bot()
      return @bot
    end

    def timer()
      return @bot.timer
    end

    def throttle(seconds)
      @throttle_secs = seconds
      @last = Time.now - @throttle_secs
    end

    def on_nick_change(method)
      LOGGER.debug("nick changes will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :nick_change, method: method)
    end

    def on_startup(method)
      LOGGER.debug("startup will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :startup, method: method)
    end

    def on_axnet_connect(method)
      LOGGER.debug("new axnet connections will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :axnet_connect, method: method)
    end

    def on_axnet_disconnect(method)
      LOGGER.debug("axnet disconnects will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :axnet_disconnect, method: method)
    end

    def on_ban_list(method)
      LOGGER.debug("banlist update invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :ban_list, method: method)
    end

    def on_user_list(method)
      LOGGER.debug("userlist update will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :user_list, method: method)
    end

    def on_channel_full(method)
      LOGGER.debug("channel is full (#471) errors will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :channel_full, method: method)
    end

    def on_invite(method)
      LOGGER.debug("channel invitations will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :invited_to_channel, method: method)
    end

    def on_banned_from_channel(method)
      LOGGER.debug("banned from channel (#474) will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :banned_from_channel, method: method)
    end

    def on_channel_keyword(method)
      LOGGER.debug("channel keyword (#475) will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :channel_keyword, method: method)
    end

    def on_channel_invite_only(method)
      LOGGER.debug("invite only (#473) will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :channel_invite_only, method: method)
    end

    def on_reload(method)
      LOGGER.debug("addon reload will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :reload, method: method)
    end

    def on_mode(*in_args)
      if (in_args.nil? || in_args.count < 2)
        raise(AddonError, "#{self.class}.on_mode called without at least one mode and a callback method")
      end
      args = in_args.flatten
      method = args.pop
      modes = args
      LOGGER.debug("channel mode change (#{modes.join(', ')}) will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :mode, method: method, modes: modes)
    end

    def wait_a_sec()
      random_sleep = SecureRandom.random_number(300) / 100.to_f
      sleep(random_sleep)
    end

    def on_irc_ban_list_end(method)
      LOGGER.debug("IRC banlist end (368) will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :irc_ban_list_end, method: method)
    end

    def on_kick(method)
      LOGGER.debug("channel kick will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :kick, method: method)
    end

    def on_self_kick(method)
      LOGGER.debug("getting kicked will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :self_kick, method: method)
    end

    def on_part(method)
      LOGGER.debug("channel part will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :part, method: method)
    end

    def on_quit(method)
      LOGGER.debug("IRC quit will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :quit, method: method)
    end

    def on_channel_sync(method)
      LOGGER.debug("channel sync will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :channel_sync, method: method)
    end

    def on_join(method)
      LOGGER.debug("channel join will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :join, method: method)
    end

    def on_dcc(command, method)
      LOGGER.debug("DCC '#{command}' will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :dcc, command: command, method: method)
    end

    def on_self_join(method)
      LOGGER.debug("channel self-join will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :self_join, method: method)
    end

    def on_channel_any(method)
      LOGGER.debug("all channel messages will invoke method '#{self.class}.#{method}'")
      @listeners.push(type: :channel_any, method: method)
    end

    def on_channel(command, method)
      if (command.is_a?(Regexp))
        LOGGER.debug("channel comand expression '#{command.source}' will invoke method '#{self.class}.#{method}'")
      else
        LOGGER.debug("channel command '#{command}' will invoke method '#{self.class}.#{method}'")
      end
      @listeners.push(type: :channel, command: command, method: method)
    end

    def on_channel_glob(text, method)
      if (text.is_a?(Regexp))
        LOGGER.debug("channel global expression '#{text.source}' will invoke method '#{self.class}.#{method}'")
      else
        LOGGER.debug("channel global text '#{text}' will invoke method '#{self.class}.#{method}'")
      end
      @listeners.push(type: :channel_glob, text: text, method: method)
    end

    def on_axnet(command, method)
      if (command.is_a?(Regexp))
        LOGGER.debug("axnet text pattern '#{command.source}' will invoke method '#{self.class}.#{method}'")
      else
        LOGGER.debug("axnet command '#{command}' will invoke method '#{self.class}.#{method}'")
      end
      @listeners.push(type: :axnet, command: command, method: method)
    end

    def on_privmsg(command, method)
      LOGGER.debug("private message '#{command}' will invoke method '#{self.class}.#{method}")
      @listeners.push(type: :privmsg, command: command, method: method)
    end

    def before_reload()
      LOGGER.debug("#{self.class}: before_reload super invoked")
    end
  end
end
