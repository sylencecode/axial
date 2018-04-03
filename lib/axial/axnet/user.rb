require 'axial/role'

module Axial
  module Axnet
    class User
      attr_accessor :id, :name, :pretty_name, :masks, :role_name, :role
      def initialize()
        @id = nil
        @name = nil
        @pretty_name = nil
        @masks = []
        @role = nil
        @role_name = nil
      end

      def self.from_model(user_model)
        user = new
        user.masks = []
        user.name = user_model.name
        user.pretty_name = user_model.pretty_name
        user_model.masks.each do |mask|
          user.masks.push(mask.mask)
        end
        user.role_name = user_model.role_name
        user.role = Role.new(user_model.role_name)

        user.id = user_model.id
        return user
      end

      def match_mask?(in_mask)
        match = false
        @masks.each do |mask|
          if (MaskUtils.masks_match?(mask, in_mask))
            match = true
            break
          end
        end
        return match
      end
    end
  end
end
