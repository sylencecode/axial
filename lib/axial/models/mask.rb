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
      
      def self.get_masks_that_match(in_mask)
        matches = []
        user_mask = Axial::MaskUtils.ensure_wildcard(in_mask)
        in_regexp = Axial::MaskUtils.get_mask_regexp(user_mask)
        self.all.each do |mask|
          match_regexp = Axial::MaskUtils.get_mask_regexp(mask.mask)
          # need to check masks both ways to ensure no duplicates
          if (match_regexp.match(user_mask))
            matches.push(mask)
          elsif (in_regexp.match(mask.mask))
            matches.push(mask)
          end
        end
        return matches
      end

      def self.get_users_from_mask(in_mask)
        possible_users = []
        in_mask = Axial::MaskUtils.ensure_wildcard(in_mask)
        in_regexp = Axial::MaskUtils.get_mask_regexp(in_mask)
        Mask.all.each do |mask|
          match_regexp = Axial::MaskUtils.get_mask_regexp(mask.mask)
          if (match_regexp.match(in_mask))
            possible_users.push(mask.user)
          elsif (in_regexp.match(mask.mask))
            possible_users.push(mask.user)
          end
        end
        return possible_users
      end

      def self.get_user_from_mask(in_mask)
        in_mask = Axial::MaskUtils.ensure_wildcard(in_mask)
        possible_users = get_users_from_mask(in_mask)
        if (possible_users.count > 1)
          raise(DuplicateUserError, "mask #{in_mask} returns more than one user: #{possible_users.collect{|user| user.pretty_name}.join(', ')}")
        end
        return possible_users.first
      end
    
      def self.create_or_find(uhost)
        mask = Axial::MaskUtils.gen_wildcard_mask(uhost)
        db_mask = self[mask: mask]
        if (db_mask.nil?)
          db_mask = self.create(mask: mask)
        end
        return db_mask
      end
    end
  end
end
