#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../lib')))

gem 'sequel'
require 'sequel'

# raise "Sure you wanna?"

# ENV['USE_SQLITE'] = 'true'

# DB_OPTIONS = {
#   adapter: 'postgres',
#   host: ENV['AXIAL_DB_HOST'],
#   database: ENV['AXIAL_DB_NAME'],
#   user: ENV['AXIAL_DB_USER'],
#   password: ENV['AXIAL_DB_PASSWORD']
# }

require_relative '../lib/axial/models/init.rb'
require_relative '../lib/axial/models/user.rb'
require_relative '../lib/axial/models/mask.rb'

 DB_CONNECTION.alter_table(:users) do
   add_column :created_by, String, size: 32, default: 'unknown'
#   add_column :password, String, size: 128
#   add_column :created, DateTime, default: Time.now
#   add_column :note, String, size: 255
#   rename_column :role, :role_name
 end

# Axial::Models::User[name: 'sylence'].update(role_name: 'root')

exit 1


#if (DB_CONNECTION.adapter_scheme == :postgres)
#  DB_CONNECTION.drop_table?(:bans, :seens, :masks, :things, :rss_feeds, :users, cacade: true)
#else
#  DB_CONNECTION.drop_table?(:bans, :seens, :masks, :things, :rss_feeds, :users)
#end

DB_CONNECTION.drop_table?(:bans)
DB_CONNECTION.create_table :bans do
  primary_key :id
  foreign_key :user_id, :users
  String :mask, size: 255
  String :reason, size: 255
  DateTime :set_at, default: Time.now
 end

DB_CONNECTION.create_table :users do
  primary_key :id
  foreign_key :user_id, :users, unique: true
  String :name, size: 32, unique: true
  String :pretty_name, size: 32
  String :role_name, size: 16, default: 'basic'
end

DB_CONNECTION.create_table :seens do
  primary_key :id
  foreign_key :user_id, :users, unique: true
  String :status, size: 255
  DateTime :last, default: Time.now
end

DB_CONNECTION.create_table :masks do
  primary_key :id
  foreign_key :user_id, :users
  String :mask, size: 128, unique: true
end

DB_CONNECTION.create_table :rss_feeds do
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

DB_CONNECTION.create_table :things do
  primary_key :id
  foreign_key :user_id, :users
  String :thing, size: 64, unique: true
  String :pretty_thing, size: 64
  String :explanation, size: 255
  DateTime :learned_at, default: Time.now
end

DB_CONNECTION.create_table :bans do
  primary_key :id
  foreign_key :user_id, :users, unique: true
  String :mask, size: 255
  String :reason, size: 255
  DateTime :set_at, default: Time.now
end

require 'axial/models/user.rb'
require 'axial/models/mask.rb'

Models::User.create_from_nickname_mask('sylence', 'sylence', '*sylence@*.sylence.org')
Models::User[name: 'sylence'].update(role_name: 'root')
