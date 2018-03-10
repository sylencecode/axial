#!/usr/bin/env ruby

require 'sequel'
require_relative '../mask_utils.rb'

# note to self: you can use this if your model does not directly imply a table
# Mask = Class.new(Sequel::Model)
# class Mask
#  set_dataset :masks
module Axial
  module Models
    class Mask < Sequel::Model

      many_to_many :nicks
      # many_to_many :nicks, left_key: :mask_id, right_key: :nick_id, join_table: :masks_nicks
      def possible_nicks()
        res = []
        nicks.each do |result|
          res.push(result.nick)
        end
        return res
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
