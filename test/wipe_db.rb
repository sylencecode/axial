#!/usr/bin/env ruby
require 'sequel'
require_relative '../lib/models/init.rb'
# DB_OPTIONS = {
#   adapter: 'postgres',
#   host: ENV['AXIAL_DB_HOST'],
#   database: ENV['AXIAL_DB_NAME'],
#   user: ENV['AXIAL_DB_USER'],
#   password: ENV['AXIAL_DB_PASSWORD']
# }
# 
# 
# DB = Sequel.connect(DB_OPTIONS)

if (DB.adapter_scheme == :postgres)
  DB.drop_table?(:masks_nicks, :seens, :nicks, :masks, :things, :rss_feeds, cascade: true)
else
  DB.drop_table?(:masks_nicks, :seens, :nicks, :masks, :things, :rss_feeds)
end

DB.create_table :nicks do
  primary_key :id
  String :nick, size: 32, unique: true
  String :pretty_nick, size: 32
end

DB.create_table :seens do
  primary_key :id
  foreign_key :nick_id, :nicks, unique: true
  String :status, size: 255
  DateTime :last, null: false
end

DB.create_table :masks do
  primary_key :id
  foreign_key :nick_id, :nicks
  String :mask, size: 128, unique: true
end

DB.create_table :rss_feeds do
  primary_key :id
  foreign_key :nick_id, :nicks, null: false
  String      :url, size: 128, null: false
  String      :pretty_url, size: 128, null: false
  String      :name, size: 32, null: false
  String      :pretty_name, size: 32, null: false
  Integer     :ingest_count, default: 0
  DateTime    :added, default: Time.now
  DateTime    :last_ingest, default: Time.now
  Boolean     :enabled, default: false
end

DB.create_table :things do
  primary_key :id
  foreign_key :nick_id, :nicks
  String :thing, size: 64, unique: true
  String :pretty_thing, size: 64
  String :explanation, size: 255
  DateTime :learned_at, default: Time.now
end

#DB.create_join_table(nick_id: :nicks, mask_id: :masks)
require_relative '../lib/models/nick.rb'
require_relative '../lib/models/mask.rb'

Axial::Models::Nick.create_from_nickname_mask('sylence', '*sylence@*.sylence.org')
