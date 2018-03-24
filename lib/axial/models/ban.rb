gem 'sequel'
require 'sequel'
require 'axial/models/init'
require 'axial/models/user'

module Axial
  module Models
    class Ban < Sequel::Model
      many_to_one :user
    end
  end
end