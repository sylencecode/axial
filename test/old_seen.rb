#!/usr/bin/env ruby
require 'pg'

@seen_db = "axial"
@seen_user = "axial"
@seen_table = "seen"
@pg = PG::Connection.new( :dbname => @seen_db, :user => @seen_user )

@pg.prepare("get_seen", "SELECT nick, uhost, status, last from #{@seen_table} WHERE nick = $1")
@pg.prepare("add_seen", "INSERT INTO #{@seen_table} (nick, uhost, status, last) VALUES ($1, $2, $3, 'now')")
@pg.prepare("update_seen", "UPDATE #{@seen_table} SET (uhost, status, last) = ($2, $3, 'now') WHERE nick = $1")

class Seen
  attr_accessor :nick, :uhost, :status, :last
  def initialize()
    @nick = ""
    @uhost = ""
    @status = ""
    @last = ""
  end
end

def update_seen(nick, uhost, status)
  if (get_seen(nick).nil?)
    @pg.exec_prepared("add_seen", [ nick, uhost, status ])
  else
    @pg.exec_prepared("update_seen", [ nick, uhost, status ])
  end
end

def get_seen(nick)
  foo = @pg.exec_prepared("get_seen", [ nick ] )
  if (foo.ntuples > 0)
    seen = Seen.new
    seen.nick = nick
    seen.uhost = foo[0]['uhost']
    seen.status = foo[0]['status']
    seen.last = foo[0]['last']
    return seen
  else
    return nil
  end
end

#@pg.exec_prepared("add_seen", [ "abc", "abc@abc.com", "leaving #foo"])
#puts foo[0].values_at('nick', 'uhost', 'status', 'last')
#puts @pg.inspect

update_seen('X-Jester', "foo@foo.com", "playing guitar 1")
update_seen('X-Jester', "foo@foo.com", "playing guitar 2")
update_seen('X-Jester', "foo@foo.com", "playing guitar 3")

seen = get_seen('X-Jester')
puts seen.inspect
