class AddonError < StandardError
end

module Axial
  # parent class for new addons
  class Addon
    attr_reader     :binds, :name, :version, :author, :throttle_secs
    attr_accessor   :last

    def initialize(bot)
      @binds            = []
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

    def dcc_broadcast(text, role = :friend)
      Handlers::DCCState.broadcast(text, role)
    end

    def throttle(seconds)
      @throttle_secs = seconds
      @last = Time.now - @throttle_secs
    end

    def on_nick_change(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_nick_change called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :nick_change, method: method, args: args)
      else
        @binds.push(type: :nick_change, method: method)
      end

      LOGGER.debug("nick changes will invoke method '#{self.class}.#{method}'")
    end

    def on_startup(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_startup called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :startup, method: method, args: args)
      else
        @binds.push(type: :startup, method: method)
      end
      LOGGER.debug("startup will invoke method '#{self.class}.#{method}'")
    end

    def on_axnet_connect(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_axnet_connect called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :axnet_connect, method: method, args: args)
      else
        @binds.push(type: :axnet_connect, method: method)
      end
      LOGGER.debug("new axnet connections will invoke method '#{self.class}.#{method}'")
    end

    def on_axnet_disconnect(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_axnet_disconnect called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :axnet_disconnect, method: method, args: args)
      else
        @binds.push(type: :axnet_disconnect, method: method)
      end
      LOGGER.debug("axnet disconnects will invoke method '#{self.class}.#{method}'")
    end

    def on_ban_list(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_ban_list called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :ban_list, method: method, args: args)
      else
        @binds.push(type: :ban_list, method: method)
      end
      LOGGER.debug("banlist update invoke method '#{self.class}.#{method}'")
    end

    def on_user_list(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_channel called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :user_list, method: method, args: args)
      else
        @binds.push(type: :user_list, method: method)
      end

      LOGGER.debug("userlist update will invoke method '#{self.class}.#{method}'")
    end

    def on_channel_full(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_channel_full called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :channel_full, method: method, args: args)
      else
        @binds.push(type: :channel_full, method: method)
      end

      LOGGER.debug("channel is full (#471) errors will invoke method '#{self.class}.#{method}'")
    end

    def on_invite(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_invite called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :invited_to_channel, method: method, args: args)
      else
        @binds.push(type: :invited_to_channel, method: method)
      end

      LOGGER.debug("channel invitations will invoke method '#{self.class}.#{method}'")
    end

    def on_banned_from_channel(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_banned_from_channel called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :banned_from_channel, method: method, args: args)
      else
        @binds.push(type: :banned_from_channel, method: method)
      end

      LOGGER.debug("banned from channel (#474) will invoke method '#{self.class}.#{method}'")
    end

    def on_channel_keyword(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_channel_keyword called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :channel_keyword, method: method, args: args)
      else
        @binds.push(type: :channel_keyword, method: method)
      end

      LOGGER.debug("channel keyword (#475) will invoke method '#{self.class}.#{method}'")
    end

    def on_channel_invite_only(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_channel_invite_only called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :channel_invite_only, method: method, args: args)
      else
        @binds.push(type: :channel_invite_only, method: method)
      end

      LOGGER.debug("invite only (#473) will invoke method '#{self.class}.#{method}'")
    end

    def on_reload(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_reload called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :reload, method: method, args: args)
      else
        @binds.push(type: :reload, method: method)
      end

      LOGGER.debug("addon reload will invoke method '#{self.class}.#{method}'")
    end

    def on_mode(*in_args)
      if (in_args.nil? || in_args.count < 2)
        raise(AddonError, "#{self.class}.on_mode called without at least one mode and a callback method")
      end
      args = in_args.flatten
      method = args.pop
      modes = args
      LOGGER.debug("channel mode change (#{modes.join(', ')}) will invoke method '#{self.class}.#{method}'")
      @binds.push(type: :mode, method: method, modes: modes)
    end

    def wait_a_sec()
      random_sleep = SecureRandom.random_number(300) / 100.to_f
      sleep(random_sleep)
    end

    def on_irc_ban_list_end(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_irc_ban_list_end called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :irc_ban_list_end, method: method, args: args)
      else
        @binds.push(type: :irc_ban_list_end, method: method)
      end

      LOGGER.debug("IRC banlist end (368) will invoke method '#{self.class}.#{method}'")
    end

    def on_kick(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_kick called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :kick, method: method, args: args)
      else
        @binds.push(type: :kick, method: method)
      end

      LOGGER.debug("channel kick will invoke method '#{self.class}.#{method}'")
    end

    def on_self_kick(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_self_kick called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :self_kick, method: method, args: args)
      else
        @binds.push(type: :self_kick, method: method)
      end

      LOGGER.debug("getting kicked will invoke method '#{self.class}.#{method}'")
    end

    def on_part(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_part called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :part, method: method, args: args)
      else
        @binds.push(type: :part, method: method)
      end

      LOGGER.debug("channel part will invoke method '#{self.class}.#{method}'")
    end

    def on_quit(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_quit called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :quit, method: method, args: args)
      else
        @binds.push(type: :quit, method: method)
      end

      LOGGER.debug("IRC quit will invoke method '#{self.class}.#{method}'")
    end

    def on_topic(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_topic called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :topic_change, method: method, args: args)
      else
        @binds.push(type: :topic_change, method: method)
      end

      LOGGER.debug("channel topic changes will invoke method '#{self.class}.#{method}'")
    end

    def on_channel_sync(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_channel_sync called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :channel_sync, method: method, args: args)
      else
        @binds.push(type: :channel_sync, method: method)
      end

      LOGGER.debug("channel sync will invoke method '#{self.class}.#{method}'")
    end

    def on_join(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_join called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :join, method: method, args: args)
      else
        @binds.push(type: :join, method: method)
      end

      LOGGER.debug("channel join will invoke method '#{self.class}.#{method}'")
    end

    def on_who_list_entry(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_who_list_entry called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :who_list_entry, method: method, args: args)
      else
        @binds.push(type: :who_list_entry, method: method)
      end

      LOGGER.debug("IRC channel who list entry (352) will invoke method '#{self.class}.#{method}'")
    end

    def on_dcc(command, *args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_dcc called without a callback method")
      end

      args = args.flatten
      if (args.first == :silent)
        silent = true
        args.shift
      else
        silent = false
      end

      if (args.empty?)
        raise(AddonError, "#{self.class}.on_dcc called without a callback method")
      else
        method = args.shift
      end

      if (command.is_a?(Regexp))
        if (args.any?)
          @binds.push(type: :dcc, command: command, method: method, args: args, silent: silent)
        else
          @binds.push(type: :dcc, command: command, method: method, silent: silent)
        end
      elsif (command.is_a?(String))
        if (args.any?)
          command.split('|').each do |command|
            @binds.push(type: :dcc, command: command, method: method, args: args, silent: silent)
          end
        else
          command.split('|').each do |command|
            @binds.push(type: :dcc, command: command, method: method, silent: silent)
          end
        end
        if (silent)
          LOGGER.debug("DCC '#{command}' will invoke method '#{self.class}.#{method}' (silently)")
        else
          LOGGER.debug("DCC '#{command}' will invoke method '#{self.class}.#{method}'")
        end
      end
    end

    def on_self_part(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_self_part called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :self_part, method: method, args: args)
      else
        @binds.push(type: :self_part, method: method)
      end
      LOGGER.debug("channel self-part will invoke method '#{self.class}.#{method}'")
    end

    def on_self_join(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_channel called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :self_join, method: method, args: args)
      else
        @binds.push(type: :self_join, method: method)
      end
      LOGGER.debug("channel self-join will invoke method '#{self.class}.#{method}'")
    end

    def on_channel_emote(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_channel_emote called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :channel_emote, method: method, args: args)
      else
        @binds.push(type: :channel_emote, method: method)
      end

      LOGGER.debug("all channel emotes will invoke method '#{self.class}.#{method}'")
    end

    def on_channel_any(*args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_channel_any called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :channel_any, method: method, args: args)
      else
        @binds.push(type: :channel_any, method: method)
      end

      LOGGER.debug("all channel messages will invoke method '#{self.class}.#{method}'")
    end

    def on_channel(command, *args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_channel called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (command.is_a?(Regexp))
        if (args.any?)
          @binds.push(type: :channel, command: command, method: method, args: args)
        else
          @binds.push(type: :channel, command: command, method: method)
        end
        LOGGER.debug("channel expression '#{command.source}' will invoke method '#{self.class}.#{method}'")
      elsif (command.is_a?(String))
        if (args.any?)
          command.split('|').each do |command|
            @binds.push(type: :channel, command: command, method: method, args: args)
          end
        else
          command.split('|').each do |command|
            @binds.push(type: :channel, command: command, method: method)
          end
        end
        LOGGER.debug("channel command '#{@bot.channel_command_character}#{command}' will invoke method '#{self.class}.#{method}'")
      end
    end

    def on_channel_leftover(text, *args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_channel_leftover called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :channel_leftover, text: text, method: method, args: args)
      else
        @binds.push(type: :channel_leftover, text: text, method: method)
      end

      if (text.is_a?(Regexp))
        LOGGER.debug("channel leftover expression '#{text.source}' will invoke method '#{self.class}.#{method}'")
      else
        LOGGER.debug("channel leftover text '#{text}' will invoke method '#{self.class}.#{method}'")
      end
    end

    def on_axnet(command, *args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_axnet called without a callback method")
      end

      args = args.flatten
      method = args.shift

      if (args.any?)
        @binds.push(type: :axnet, command: command, method: method, args: args)
      else
        @binds.push(type: :axnet, command: command, method: method)
      end

      if (command.is_a?(Regexp))
        LOGGER.debug("axnet text pattern '#{command.source}' will invoke method '#{self.class}.#{method}'")
      else
        LOGGER.debug("axnet command '#{command}' will invoke method '#{self.class}.#{method}'")
      end
    end

    def on_privmsg(command, *args)
      if (args.nil? || args.flatten.empty?)
        raise(AddonError, "#{self.class}.on_privmsg called without a callback method")
      end

      args = args.flatten
      if (args.first == :silent)
        silent = true
        args.shift
      else
        silent = false
      end

      if (args.empty?)
        raise(AddonError, "#{self.class}.on_privmsg called without a callback method")
      else
        method = args.shift
      end

      if (command.is_a?(Regexp))
        if (args.any?)
          @binds.push(type: :privmsg, command: command, method: method, args: args, silent: silent)
        else
          @binds.push(type: :privmsg, command: command, method: method, silent: silent)
        end
        if (silent)
          LOGGER.debug("private message expression '#{command.source}' will invoke method '#{self.class}.#{method}' (silently)")
        else
          LOGGER.debug("private message expression '#{command.source}' will invoke method '#{self.class}.#{method}'")
        end
      elsif (command.is_a?(String))
        if (args.any?)
          command.split('|').each do |command|
            @binds.push(type: :privmsg, command: command, method: method, args: args, silent: silent)
          end
        else
          command.split('|').each do |command|
            @binds.push(type: :privmsg, command: command, method: method, silent: silent)
          end
        end
        if (silent)
          LOGGER.debug("private message command '#{@bot.channel_command_character}#{command}' will invoke method '#{self.class}.#{method}' (silently)")
        else
          LOGGER.debug("private message command '#{@bot.channel_command_character}#{command}' will invoke method '#{self.class}.#{method}'")
        end
      end
    end

    def reply(source, nick, text)
      if (source.is_a?(IRCTypes::Channel))
        source.message("#{nick.name}: #{text}")
      else
        source.message(text)
      end
    end

    def dcc_wrapper(*args)
      source = args.shift
      if (source.is_a?(IRCTypes::Channel))
        nick    = args.shift
        command = args.shift
        method  = args.shift
        user    = user_list.get_from_nick_object(nick)
      elsif (source.is_a?(IRCTypes::Nick))
        nick    = source
        command = args.shift
        method  = args.shift
        user    = user_list.get_from_nick_object(nick)
      elsif (source.is_a?(IRCTypes::DCC))
        nick      = IRCTypes::Nick.new(nil)
        nick.name = source.user.pretty_name
        command   = args.shift
        method    = args.shift
        user      = source.user
      end
      self.send(method, source, user, nick, command)
    end

    def before_reload()
      LOGGER.debug("#{self.class}: before_reload super invoked")
    end

    def dcc_access_denied(source)
      if (source.is_a?(IRCTypes::DCC))
        source.message(Constants::ACCESS_DENIED)
      end
    end
  end
end
