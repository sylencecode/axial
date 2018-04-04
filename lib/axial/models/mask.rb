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
      
      def self.create_or_find(uhost)
        mask = MaskUtils.gen_wildcard_mask(uhost)
        db_mask = self[mask: mask]
        if (db_mask.nil?)
          db_mask = self.create(mask: mask)
        end
        return db_mask
      end
    end
  end
end
