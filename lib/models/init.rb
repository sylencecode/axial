gem 'sequel'
require 'sequel'

class DatabaseError < StandardError
end

DB_OPTIONS = {
  adapter: 'postgres'.freeze,
  host: ENV['AXIAL_DB_HOST'].freeze,
  database: ENV['AXIAL_DB_NAME'].freeze,
  user: ENV['AXIAL_DB_USER'].freeze,
  password: ENV['AXIAL_DB_PASSWORD'].freeze
}.freeze

DB = Sequel.connect(DB_OPTIONS)