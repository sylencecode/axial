require 'sequel'

class DatabaseError < StandardError
end

DB_OPTIONS = {
  adapter: 'postgres',
  host: ENV['AXIAL_DB_HOST'],
  database: ENV['AXIAL_DB_NAME'],
  user: ENV['AXIAL_DB_USER'],
  password: ENV['AXIAL_DB_PASSWORD']
}

DB = Sequel.connect(DB_OPTIONS)

