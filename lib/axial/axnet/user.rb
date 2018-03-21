module Axial
  module Axnet
    class User
      attr_accessor :id, :name, :pretty_name, :masks, :role
      def initialize()
        @id = nil
        @name = nil
        @pretty_name = nil
        @masks = []
        @role = nil
      end

      def self.from_model(user_model)
        user = new
        user.masks = []
        user.name = user_model.name
        user.pretty_name = user_model.pretty_name
        user_model.masks.each do |mask|
          user.masks.push(mask.mask)
        end
        user.role = user_model.role
        user.id = user_model.id
        return user
      end
    end
  end
end
