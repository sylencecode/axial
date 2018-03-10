require 'pg'

# holy shit i need to fix this

module Seen
  class SeenResult
    attr_accessor :nick, :uhost, :status, :last
    def initialize()
      @last = nil
      @nick = ""
      @uhost = ""
      @status = ""
    end
  
    def to_irc()
      seen_ago = ::TimeSpan.new(@last, Time.now)
      return "#{@nick} (#{@uhost}) was last seen #{@status} #{seen_ago.approximate_to_s} ago."
    end
  end

  class Search
    @@seen_db = "axial"
    @@seen_user = "axial"
    @@seen_table = "seen"

    def initialize()
      @pg = nil
    end

    def connect()
      @pg = PG::Connection.new( :dbname => @@seen_db, :user => @@seen_user )
      @pg.prepare("get_seen", "SELECT id, nick, uhost, status, last from #{@@seen_table} WHERE LOWER(nick) = LOWER($1)")
      @pg.prepare("add_seen", "INSERT INTO #{@@seen_table} (nick, uhost, status, last) VALUES ($1, $2, $3, 'now')")
      @pg.prepare("update_seen", "UPDATE #{@@seen_table} SET (nick, uhost, status, last) = ($1, $2, $3, 'now') WHERE id = $4")
    end
    private :connect

    def disconnect()
      @pg.close
    end
    private :disconnect

    def query_seen(nick)
      connect
      query = @pg.exec_prepared("get_seen", [ nick ] )
      if (query.ntuples > 0)
        result = query
      else
        result = nil
      end
      disconnect
      return result
      private :query_seen
    end

    def search(nick)
      query = query_seen(nick)
      if (!query.nil?)
        seen = SeenResult.new
        seen.nick = query[0]['nick']
        seen.uhost = query[0]['uhost']
        seen.status = query[0]['status']
        time_string = query[0]['last']
        if (time_string =~ /(\d+)-(\d+)-(\d+) (\d+):(\d+):(\d+)/)
          # build a Time object out of the psql timestamp
          year = $1
          month = $2
          day = $3
          hour = $4
          minute = $5
          second = $6
          seen.last = Time.new(year, month, day, hour, minute, second)
        else
          # bad timestamp, return nil
          return nil
        end
        return seen
      else
        return nil
      end
    end
  
    def update_seen(nick, uhost, status)
      connect
      seen = query_seen(nick)
      if (seen.nil?)
        @pg.exec_prepared("add_seen", [ nick, uhost, status ])
      else
        id = query['id']
        @pg.exec_prepared("update_seen", [ nick, uhost, status, id ])
      end
      disconnect
    end
  end
end
