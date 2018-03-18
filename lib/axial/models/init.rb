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

if (ENV.has_key?('USE_SQLITE') && ENV['USE_SQLITE'].casecmp('true').zero?)
  DB_CONNECTION = Sequel.sqlite('./test.db')
else
  DB_CONNECTION = Sequel.connect(DB_OPTIONS)
end