gem 'sequel'
require 'sequel'
require 'axial/models/init'
require 'axial/models/user'

module Axial
  module Models
    class Ban < Sequel::Model
      def self.delete_or_unknown(user_id)
        if (DB_CONNECTION[:bans].nil?)
          return
        end

        unknown_user = Models::User[name: 'unknown']
        unknown_user_id = (unknown_user.nil?) ? 0 : unknown_user.id

        if (unknown_user_id.zero?)
          DB_CONNECTION[:bans].where(user_id: user_id).delete
        else
          DB_CONNECTION[:bans].where(user_id: user_id).update(user_id: unknown_user_id)
        end
      end

      def self.get_bans_from_overlap(in_mask)
        possible_bans = []
        Models::Ban.all.each do |ban_model|
          if (MaskUtils.masks_overlap?(ban_model.mask, in_mask))
            possible_bans.push(ban_model)
          end
        end
        return possible_bans
      end

      many_to_one :user
    end
  end
end
