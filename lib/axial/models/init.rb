gem 'sqlite3'
gem 'pg'
gem 'sequel'
require 'pg'
require 'sequel'
require 'sqlite3'

class DatabaseError < StandardError
end

DB_OPTIONS = {
  adapter: 'postgres'.freeze,
  host: ENV['AXIAL_DB_HOST'].freeze,
  database: ENV['AXIAL_DB_NAME'].freeze,
  user: ENV['AXIAL_DB_USER'].freeze,
  password: ENV['AXIAL_DB_PASSWORD'].freeze
}.freeze

if (ENV.key?('USE_SQLITE') && ENV['USE_SQLITE'].casecmp('true').zero?)
  sqlite_db = File.join(File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..')), 'test.db')
  DB_CONNECTION = Sequel.sqlite(sqlite_db)
else
  DB_CONNECTION = Sequel.connect(DB_OPTIONS)
end

Sequel::Model.plugin :after_initialize
Sequel::Model.plugin :json_serializer
