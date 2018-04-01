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
      
      def self.get_masks_that_match(left_mask)
        matches = []
        self.all.each do |right_mask|
          if (masks_match?(left_mask, right_mask))
            matches.push(right_mask)
          end
        end
        return matches.uniq
      end

      def self.get_users_from_mask(in_mask)
        possible_users = []
        Mask.all.each do |mask|
          if (MaskUtils.masks_match?(mask.mask, in_mask))
            possible_users.push(mask.user)
          end
        end
        return possible_users.uniq
      end

      def get_users_from_overlaps(in_mask)
      end

      def self.get_user_from_mask(in_mask)
        possible_users = get_users_from_mask(in_mask)
        if (possible_users.count > 1)
          raise(DuplicateUserError, "mask #{in_mask} returns more than one user: #{possible_users.collect{ |user| user.pretty_name }.join(', ')}")
        end
        return possible_users.uniq.first
      end
    
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
