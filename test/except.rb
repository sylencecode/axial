#!/usr/bin/env ruby

$LOAD_PATH.unshift('../lib')
require_relative '../lib/axial/models/user.rb'
require_relative '../lib/axial/models/mask.rb'
require_relative '../lib/axial/models/thing.rb'
require_relative '../lib/axial/models/rss_feed.rb'
require_relative '../lib/axial/models/ban.rb'

includes = {
  masks: { except: :id },
  seen: { except: [ :id, :user_id ] },
  things: { except: [ :id, :user_id ] },
  rss_feeds: { except: [ :id, :user_id ] },
  bans: { except: [ :id, :user_id ] }
}

foo = JSON.parse(Axial::Models::User[name: 'fope'].to_json(include: includes, except: :id))
puts JSON.pretty_generate(foo)
