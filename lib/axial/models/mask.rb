gem 'sequel'
require 'sequel'
require 'axial/models/init'
require 'axial/mask_utils'
require 'axial/models/user'

# note to self: you can use this if your model does not directly imply a table
# Mask = Class.new(Sequel::Model)
# class Mask
#  set_dataset :masks
module Axial
  module Models
    class Mask < Sequel::Model

      many_to_one :user
    end
  end
end
