#!/usr/bin/env ruby

require 'sequel'

DB_OPTIONS = {
  adapter: 'postgres',
  host: ENV['AXIAL_DB_HOST'],
  database: ENV['AXIAL_DB_NAME'],
  user: ENV['AXIAL_DB_USER'],
  password: ENV['AXIAL_DB_PASSWORD']
}

DB = Sequel.connect(DB_OPTIONS)

# if (DB.adapter_scheme == :postgres)
#   DB.drop_table?(:masks_nicks, :seens, :nicks, :masks, cascade: true)
# else
#   DB.drop_table?(:masks_nicks, :seens, :nicks, :masks)
# end
# 
# DB.create_table :nicks do
#   primary_key :id
#   String :nick, size: 32, unique: true
#   String :pretty_nick, size: 32
# end
# 
# DB.create_table :seens do
#   primary_key :id
#   foreign_key :nick_id, :nicks, null: false, unique: true
#   String :status, size: 255
#   DateTime :last, null: false
# end
# 
# DB.create_table :masks do
#   primary_key :id
#   String :mask, size: 128
# end
# 
# DB.create_join_table(nick_id: :nicks, mask_id: :masks)
