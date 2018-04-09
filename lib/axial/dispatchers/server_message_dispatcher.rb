require 'axial/handlers/patterns'

module Axial
  module Dispatchers
    class ServerMessageDispatcher
      include Handlers::Patterns

      def initialize(bot)
        @bot = bot
      end

      def dispatch(text)
        case text
          when Channel::BAN_LIST_END
            @bot.channel_handler.handle_ban_list_end(Regexp.last_match[1])
          when Channel::BAN_LIST_ENTRY
            channel, mask, who_set, set_at = Regexp.last_match.captures
            @bot.channel_handler.handle_ban_list_entry(channel, mask, who_set, set_at)
          when Channel::BANNED_FROM_CHANNEL
            @bot.channel_handler.handle_banned_from_channel(Regexp.last_match[1])
          when Channel::CHANNEL_FULL
            @bot.channel_handler.handle_channel_full(Regexp.last_match[1])
          when Channel::CHANNEL_INVITE_ONLY
            @bot.channel_handler.handle_channel_invite_only(Regexp.last_match[1])
          when Channel::CHANNEL_KEYWORD
            @bot.channel_handler.handle_channel_keyword(Regexp.last_match[1])
          when Channel::CREATED
            channel_name, created_at = Regexp.last_match.captures
            @bot.channel_handler.dispatch_created(channel_name, created_at.to_i)
          when Channel::INITIAL_MODE
           channel_name, initial_mode = Regexp.last_match.captures
           @bot.channel_handler.handle_initial_mode(channel_name, initial_mode)
          when Channel::INITIAL_TOPIC
           channel_name, initial_topic = Regexp.last_match.captures
           @bot.channel_handler.handle_initial_topic(channel_name, initial_topic)
          when Channel::INVITED
            uhost, channel_name = Regexp.last_match.captures
            @bot.channel_handler.handle_invited_to_channel(uhost, channel_name)
          when Channel::JOIN
            uhost, channel_name = Regexp.last_match.captures
            @bot.channel_handler.dispatch_join(uhost, channel_name)
          when Channel::KICK, Channel::KICK_NO_REASON
            uhost, channel_name, kicked_nick_name, reason = Regexp.last_match.captures
            @bot.channel_handler.dispatch_kick(uhost, channel_name, kicked_nick_name, reason.strip)
          when Channel::MODE
            uhost, channel_name, mode = Regexp.last_match.captures
            @bot.channel_handler.dispatch_mode(uhost, channel_name, mode)
          when Channel::NICK_CHANGE
            uhost, new_nick = Regexp.last_match.captures
            @bot.channel_handler.dispatch_nick_change(uhost, new_nick)
          when Channel::NOT_OPERATOR
            LOGGER.warn("I tried to do something to #{Regexp.last_match[1]} but I'm not opped.")
          when Channel::PART, Channel::PART_NO_REASON
            uhost, channel_name, reason = Regexp.last_match.captures
            @bot.channel_handler.dispatch_part(uhost, channel_name, reason)
          when Channel::TOPIC_CHANGE
            uhost, channel_name, topic = Regexp.last_match.captures
            @bot.channel_handler.handle_topic_change(uhost, channel_name, topic)
          when Channel::QUIT
            uhost, reason = Regexp.last_match.captures
            @bot.channel_handler.dispatch_quit(uhost, reason)
          when Channel::WHO_LIST_END
            @bot.channel_handler.handle_who_list_end(Regexp.last_match[1])
          when Channel::WHO_LIST_ENTRY
            channel_name, user, host, server, nick, mode, junk, realname = Regexp.last_match.captures
            uhost = "#{nick}!#{user}@#{host}"
            @bot.channel_handler.handle_who_list_entry(nick, uhost, channel_name, mode)
          when Messages::NOTICE, Messages::NOTICE_NOPREFIX
            uhost, dest, text = Regexp.last_match.captures
            @bot.message_handler.dispatch_notice(uhost, dest, text)
          when Messages::PRIVMSG
            uhost, dest, text = Regexp.last_match.captures
            @bot.message_handler.dispatch_privmsg(uhost, dest, text)
          when Server::ISON_REPLY
            @bot.server_handler.handle_ison_reply(Regexp.last_match[1])
          when Server::MOTD_BEGIN
            LOGGER.info("begin motd")
          when Server::MOTD_END, Server::MOTD_ERROR
            LOGGER.info("end of motd, performing autojoin")
            @bot.server_interface.set_invisible
            @bot.server_interface.whois_myself
            @bot.auto_join_channels
          when Server::MOTD_ENTRY
            LOGGER.info("motd: #{Regexp.last_match[1]}")
          when Server::NICK_ERRONEOUS
            @bot.server_interface.nick_in_use(Regexp.last_match[1], :erroneous)
          when Server::NICK_IN_USE
            @bot.server_interface.nick_in_use(Regexp.last_match[1], :in_use)
          when Server::NICK_MODE
            nick_name, user_mode = Regexp.last_match.captures
            LOGGER.info("server sets user mode for #{nick_name}: #{user_mode}")
          when Server::PARAMETERS
            params = Regexp.last_match[1]
            if (params =~ /MODES=(\d+)/)
              @bot.server_interface.max_modes = Regexp.last_match[1].to_i
            end
            if (params =~ /NICKLEN=(\d+)/)
              @bot.server_interface.max_nick_length = Regexp.last_match[1].to_i
            end
          when Server::UNKNOWN_COMMAND
            LOGGER.warn("server responded with unknown command: '#{Regexp.last_match[1]}'")
          when Server::WHOIS_UHOST
            nick, ident, host = Regexp.last_match.captures
            @bot.server_handler.handle_whois_uhost(nick, ident, host)
          when Server::ANY_NUMERIC
            numeric, text = Regexp.last_match.captures
            numeric = numeric.to_i
            if (!Server::SILENCE_NUMERICS.include?(numeric))
              LOGGER.debug("[#{numeric}] #{text}")
            end
          else
            LOGGER.debug("Unhandled server message: #{text}")
        end
      rescue Exception => ex
        LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
        ex.backtrace.each do |i|
          LOGGER.error(i)
        end
      end
    end
  end
end
