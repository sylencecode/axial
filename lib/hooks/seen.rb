module Axial
  module Hooks
    module Seen
      def handle_seen(nick, channel, seen_nick)
        if (nick.downcase == seen_nick.downcase)
          send_channel(channel, "#{nick}: Try using a mirror?")
          return
        # if seen_nick on channel...
       # elsif
       #   return
        end

        if (seen_nick.length > 31)
          seen_nick = seen_nick[0..31]
        end

        # else - also, fix this OO nightmare
#        search = ::Seen::Search.new
#        seen = search.search(seen_nick)
#        if (!seen.nil?)
          send_channel(channel, "#{$irc_gray}[#{$irc_magenta}seen#{$irc_reset} #{$irc_gray}::#{$irc_reset} #{$irc_darkmagenta}#{nick}#{$irc_gray}]#{$irc_reset} #{seen.to_irc}")
#        else
#          send_channel(channel, "#{nick}: I haven't seen #{seen_nick} recently.")
#        end
      end
    end
  end
end
