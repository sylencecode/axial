module Axial
  module Handlers
    module Patterns
      module Channel
        BAN_LIST_ENTRY        = /^:{0,1}\S+ 367 \S+ (\S+) (\S+) (\S+) (\S+)/
        BAN_LIST_END          = /^:{0,1}\S+ 368 \S+ (\S+)/
        BANNED_FROM_CHANNEL   = /^:{0,1}\S+ 474 \S+ (\S+)/
        CHANNEL_KEYWORD       = /^:{0,1}\S+ 475 \S+ (\S+)/
        CHANNEL_FULL          = /^:{0,1}\S+ 471 \S+ (\S+)/
        CHANNEL_INVITE_ONLY   = /^:{0,1}\S+ 473 \S+ (\S+)/
        CREATED               = /^:{0,1}\S+ 329 \S+ (\S+) (\S+)/
        INITIAL_MODE          = /^:{0,1}\S+ 324 \S+ (\S+) (\S+)/
        INVITED               = /^:{0,1}(\S+) INVITE \S+ :{0,1}(\S+)/
        JOIN                  = /^:{0,1}(\S+) JOIN :{0,1}(\S+)/
        KICK                  = /^:{0,1}(\S+) KICK (\S+) (\S+) :{0,1}(.*)/
        KICK_NO_REASON        = /^:{0,1}(\S+) KICK (\S+) (\S+)/
        MODE                  = /^:{0,1}(\S+) MODE (#\S+) (.*)/
        NAMES_LIST_ENTRY      = /^:{0,1}\S+ 353 (.*)/
        NAMES_LIST_END        = /^:{0,1}\S+ 366 (.*)/
        NICK_CHANGE           = /^:{0,1}(\S+) NICK :{0,1}(\S+)/
        NOT_OPERATOR          = /^:{0,1}\S+ 482 (\S+)/
        PART                  = /^:{0,1}(\S+) PART (\S+) :{0,1}(.*)/
        PART_NO_REASON        = /^:{0,1}(\S+) PART (\S+)/
        QUIT                  = /^:{0,1}(\S+) QUIT :{0,1}(.*)/
        WHO_LIST_END          = /^:{0,1}\S+ 315 \S+ (\S+)/
        WHO_LIST_ENTRY        = /^:{0,1}\S+ 352 \S+ (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (.*)/
      end

      module Server
        ANY_NUMERIC           = /^:{0,1}\S+ ([0-9][0-9][0-9]) \S+ :{0,1}(.*)/
        MOTD_BEGIN            = /^:{0,1}\S+ 375/
        MOTD_END              = /^:{0,1}\S+ 376/
        MOTD_ENTRY            = /^:{0,1}\S+ 372 \S+ :{0,1}(.*)/
        MOTD_ERROR            = /^:{0,1}\S+ 422/
        NICK_IN_USE           = /^:{0,1}\S+ 433 \S+ :{0,1}(.*)/
        NICK_MODE             = /^(\S+) MODE :{0,1}(.*)/
        PARAMETERS            = /^:{0,1}\S+ 005 \S+ :{0,1}(.*)/
        WHOIS_UHOST           = /^:{0,1}\S+ 311 \S+ (\S+) (\S+) (\S+)/
      end

      module Messages
        PRIVMSG           = /^:{0,1}(\S+) PRIVMSG (\S+) :{0,1}(.*)/

        NOTICE_NOPREFIX   = /^NOTICE \S+ :{0,1}(.*)/
        NOTICE            = /^:{0,1}(\S+) NOTICE (\S+) :{0,1}(.*)/
      end
    end
  end
end
