#!/usr/bin/env ruby

$LOAD_PATH.unshift('../lib')

gem 'sequel'
require 'sequel'
require_relative '../lib/axial/models/init.rb'
 DB_OPTIONS = {
   adapter: 'postgres',
   host: ENV['AXIAL_DB_HOST'],
   database: ENV['AXIAL_DB_NAME'],
   user: ENV['AXIAL_DB_USER'],
   password: ENV['AXIAL_DB_PASSWORD']
 }
 
 
 DB = Sequel.connect(DB_OPTIONS)

#raise "Sure you wanna?"
#exit 1

#ENV['USE_SQLITE'] = 'true'
#DB = Sequel.sqlite('../test.db')

#if (DB.adapter_scheme == :postgres)
#  DB.drop_table?(:bans, :seens, :masks, :things, :rss_feeds, :users, cacade: true)
#else
#  DB.drop_table?(:bans, :seens, :masks, :things, :rss_feeds, :users)
#end

DB.drop_table?(:bans)
DB.create_table :bans do
  primary_key :id
  foreign_key :user_id, :users, unique: true
  String :mask, size: 255
  String :reason, size: 255
  DateTime :set_at, default: Time.now
end

exit 1

DB.create_table :users do
  primary_key :id
  foreign_key :user_id, :users, unique: true
  String :name, size: 32, unique: true
  String :pretty_name, size: 32
  String :role, size: 16, default: 'friend'
end

DB.create_table :seens do
  primary_key :id
  foreign_key :user_id, :users, unique: true
  String :status, size: 255
  DateTime :last, default: Time.now
end

DB.create_table :masks do
  primary_key :id
  foreign_key :user_id, :users
  String :mask, size: 128, unique: true
end

DB.create_table :rss_feeds do
  primary_key :id
  foreign_key :user_id, :users, null: false
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
  foreign_key :user_id, :users
  String :thing, size: 64, unique: true
  String :pretty_thing, size: 64
  String :explanation, size: 255
  DateTime :learned_at, default: Time.now
end

DB.create_table :bans do
  primary_key :id
  foreign_key :user_id, :users, unique: true
  String :mask, size: 255
  String :reason, size: 255
  DateTime :set_at, default: Time.now
end

#DB.create_join_table(user_id: :users, mask_id: :masks)
require 'axial/models/user.rb'
require 'axial/models/mask.rb'

Axial::Models::User.create_from_nickname_mask('sylence', '*sylence@*.sylence.org')
Axial::Models::User[name: 'sylence'].update(role: 'director')
