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
           @bot.channel_handler.dispatch_initial_mode(channel_name, initial_mode)
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
          when Channel::NAMES_LIST_ENTRY
            LOGGER.debug(Regexp.last_match[1])
          when Channel::NAMES_LIST_END
            LOGGER.debug(Regexp.last_match[1])
          when Channel::NICK_CHANGE
            uhost, new_nick = Regexp.last_match.captures
            @bot.channel_handler.dispatch_nick_change(uhost, new_nick)
          when Channel::NOT_OPERATOR
            LOGGER.warn("I tried to do something to #{Regexp.last_match[1]} but I'm not opped.")
          when Channel::PART, Channel::PART_NO_REASON
            uhost, channel_name, reason = Regexp.last_match.captures
            @bot.channel_handler.dispatch_part(uhost, channel_name, reason)
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
          when Server::MOTD_BEGIN
            LOGGER.info("begin motd")
          when Server::MOTD_END, Server::MOTD_ERROR
            LOGGER.info("end of motd, performing autojoin")
            @bot.whois_myself
            @bot.autojoin_channels
          when Server::MOTD_ENTRY
            LOGGER.info("motd: #{Regexp.last_match[1]}")
          when Server::PARAMETERS
            if (Regexp.last_match[1] =~ /MODES=(\d+)/)
              @bot.server.max_modes = Regexp.last_match[1]
            end
          when Server::WHOIS_UHOST
            nick, ident, host = Regexp.last_match.captures
            @bot.server_handler.dispatch_whois_uhost(nick, ident, host)
          when Server::ANY_NUMERIC
            LOGGER.warn("[#{Regexp.last_match[1]}] #{Regexp.last_match[2]}")
          else
            LOGGER.warn("Unhandled server message: #{text}")
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
