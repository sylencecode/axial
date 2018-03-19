module Axial
  module Handlers
    module Patterns
      module Channel
        JOIN              = /^:{0,1}(\S+)\s+JOIN\s+:{0,1}(\S+)/
        MODE              = /^:{0,1}(\S+)\s+MODE\s+(#\S+)\s+(.*)/
        QUIT              = /^:{0,1}(\S+)\s+QUIT\s+(\S+)\s+:{0,1}(.*)/
        QUIT_NO_REASON    = /^:{0,1}(\S+)\s+QUIT\s+(\S+)/
        PART              = /^:{0,1}(\S+)\s+PART\s+(\S+)\s+:{0,1}(.*)/
        PART_NO_REASON    = /^:{0,1}(\S+)\s+PART\s+(\S+)/
        WHO_LIST_END      = /^315\s+(\S+)/
        WHO_LIST_ENTRY    = /^352\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+) (.*)/
        NAMES_LIST_ENTRY  = /^353\s+(.*)/
        NAMES_LIST_END    = /^366/
        NOT_OPERATOR      = /^482\s+(\S+)/
      end

      module Server
        ANY_NUMERIC       = /^:{0,1}\S+\s+([0-9][0-9][0-9]) \S+ :{0,1}(.*)/
        PARAMETERS        = /^:{0,1}\S+\s+005 \S+ :{0,1}(.*)/
        MOTD_BEGIN        = /^:{0,1}\S+\s+375/
        MOTD_ENTRY        = /^:{0,1}\S+\s+372 \S+ :{0,1}(.*)/
        MOTD_END          = /^:{0,1}\S+\s+376/
        MOTD_ERROR        = /^:{0,1}\S+\s+422/
        NICK_IN_USE       = /^:{0,1}\S+\s+433 \S+ :{0,1}(.*)/
        NICK_MODE         = /^(\S+)\s+MODE\s+:{0,1}(.*)/
      end

      module Messages
        PRIVMSG           = /^:{0,1}(\S+)\s+PRIVMSG\s+(\S+)\s+:{0,1}(.*)/

        NOTICE_NOPREFIX   = /^NOTICE \S+ :{0,1}(.*)/
        NOTICE            = /^:{0,1}(\S+) NOTICE (\S+) :{0,1}(.*)/
      end
    end
  end
end
