#!/usr/bin/env ruby

require 'sequel'

db_options = {
  adapter: 'postgres',
  host: 'localhost',
  database: 'axial',
  user: 'axial'
}

# DB = Sequel.connect(db_options)
DB = Sequel.sqlite('./foo.db')

if DB.adapter_scheme == :postgres
  DB.drop_table?(:masks_nicks, :seens, :nicks, :masks, cascade: true)
else
  DB.drop_table?(:masks_nicks, :seens, :nicks, :masks)
end

DB.create_table :nicks do
  primary_key :id
  String :nick, size: 32
  String :prettynick, size: 32
end

DB.create_table :seens do
  #  primary_key :id
  #  foreign_key :nick_id, :nicks, null: false, unique: true
  foreign_key :id, :nicks, primary_key: true
  String :status, size: 255
  DateTime :last, null: false
end

DB.create_table :masks do
  primary_key :id
  String :mask, size: 128
end

DB.create_join_table(nick_id: :nicks, mask_id: :masks)

# note to self: you can use this if your model does not directly imply a table
# Mask = Class.new(Sequel::Model)
# class Mask
#  set_dataset :masks
class Mask < Sequel::Model
  many_to_many :nicks
  # many_to_many :nicks, left_key: :mask_id, right_key: :nick_id, join_table: :masks_nicks
  def possible_nicks
    res = []
    nicks.each do |result|
      res.push(result.nick)
    end
    res
  end
end

# note to self: you can use this if your model does not directly imply a table
# Nick = Class.new(Sequel::Model)
# class Nick
#  set_dataset :nicks
class Nick < Sequel::Model
  many_to_many :masks
  one_to_one :seen, key: :id
  # many_to_many :masks, left_key: :nick_id, right_key: :mask_id, join_table: :masks_nicks
  def possible_masks
    res = []
    masks.each do |result|
      res.push(result.mask)
    end
    res
  end

  def include_mask?(in_mask)
    found = false
    masks.each do |mask|
      found = true if mask.mask.casecmp(in_mask.downcase).zero?
    end
    found
  end
end

# Store last seen information, use primary key of nick table as primary key for this table
class Seen < Sequel::Model
  many_to_one :nick, key: :id
end


@do_not_wildcard = [
  '*.irccloud.com'
]

def mask_ipv4(host)
  host_parts = host.split(/\./)
  host_parts.pop
  host = host_parts.join('.') + '.*'
  return host
end

def mask_ipv6(host)
  host_parts = host.split(/:/)
  host_parts.pop
  host = host_parts.join(':') + ':*'
  return host
end

def mask_dns(host)
  host_parts = host.split(/\./)
  if host_parts.count > 2
    host_parts.shift
    host = '*.' + host_parts.join('.')
  end
  return host
end

def gen_wildcard_host(host)
  @do_not_wildcard.each do |domain|
    wc = get_irc_regexp(domain)
    return host if wc.match(host)
  end

  if host =~ /^\d+\.\d+\.\d+\.\d+$/ # ipv4
    return mask_ipv4(host)
#  elsif host =~ /^\S+:\S+:\S+:\S+:\S+:\S+:\S+:\S+$/ # ipv6
  elsif host =~ /^\S+:.*:.*:.*:.*:.*:.*:\S+$/ # ipv6
    return mask_ipv6(host)
  else # dns
    return mask_dns(host)
  end
end

def strip_ident(in_ident)
  ident = in_ident.strip
  ident.gsub!(/^~/, '')
  if (ident.empty?)
    ident = '*'
  elsif (ident != '*')
    ident = '*' + ident
  end
  return ident
end

def gen_wildcard_mask(in_mask)
  mask = in_mask.strip
  if mask =~ /^(\S+)!(\S+)@(\S+)$/
    # TODO: mode to decide whether to include the nick in the mask?
    # nick = Regexp.last_match[1]
    nick = '*'
    ident = Regexp.last_match[2]
    host = Regexp.last_match[3]
    ident = strip_ident(ident)
    host = gen_wildcard_host(host)
    return "#{nick}!#{ident}@#{host}"
  else
    raise(RuntimeError, "to do: ensure you're checking for empty masks")
  end
end

def get_irc_regexp(mask)
  Regexp.new('^' + Regexp.escape(mask).gsub(/\\\*/, '.*').gsub(/\\\?/, '?') + '$')
end

statuses = [
  'Leaving IRC 1',
  'Leaving IRC 2',
  'Leaving IRC 3',
  'Leaving IRC 4'
]
nicks = [
  'Nick1',
  'Nick2',
  'Nick3',
  'Nick4'
]
masks = [
  'X-Jester!~xjester@love.foo.dong.org',
  'X-Jester!xjester@asdf-1234.foo.irccloud.com',
  'X-Jester!~peeps@192.168.1.9',
  'X-Jester!~foo@2001:19f0:7400:8645::dab:eeec:0',
#  'X-Jester!~foo@2001:19f0:7400:8645:10:dab:eeec:0',
  'X-Jester!foo@test.com'
]

# sample nick registration with mask
nicks.each_with_index do |nickname, i|
  nick = Nick[nick: nickname.downcase]
  if nick.nil?
    nick = Nick.create(nick: nickname.downcase, prettynick: nickname)
    nick.seen = Seen.create(status: statuses[i], last: Time.now)
  else
    nick.seen.status = statuses[i]
    nick.seen.last = Time.now
    nick.seen.save
  end
  mask = Mask[mask: masks[i]]
  if mask.nil?
    mask = Mask.create(mask: gen_wildcard_mask(masks[i]))
    nick.add_mask(mask)
  elsif !nick.include_mask?(masks[i])
    nick.add_mask(gen_wildcard_mask(masks[i]))
  else
    puts "Already had #{masks[i]}"
  end
end

puts '---records created---'

puts "nicks for #{Mask[2].mask}: #{Mask[2].possible_nicks.inspect}"
puts "masks for #{Nick[1].nick}: #{Nick[1].possible_masks.inspect}"
puts "masks for #{Nick[2].nick}: #{Nick[2].possible_masks.inspect}"
puts "masks for #{Nick[3].nick}: #{Nick[3].possible_masks.inspect}"
puts "masks for #{Nick[4].nick}: #{Nick[4].possible_masks.inspect}"

# puts "seen for #{Nick[1].nick}: #{Seen[Nick[1]].inspect]}"
puts "seen for #{Nick[1].nick}: #{Nick[1].seen.status}"
puts "masks for #{Seen[1].nick.nick}: #{Seen[1].nick.masks}"

# masks.each do |mask|
#  puts gen_wildcard_mask(mask)
# end

# if maskmatch.match(test)
#   puts 'match|#{test}|#{maskmatch.inspect}'
# else
#   puts 'nomatch|#{test}|#{maskmatch.inspect}'
# end
# test = 'X-Jester!~xjester@suck.a.fat.dong.org'
# should = '*@*.dong.org'

# maskmatch = Regexp.new('^' + should + '$')
# puts maskmatch.inspect
# Mask.grep(:mask, '%.suck.org').each do |i|
#   puts i.inspect
# end
