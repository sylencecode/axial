require 'axial/role'
require 'axial/colors'

module Axial
  module Axnet
    class User
      attr_accessor :id, :name, :pretty_name, :masks, :role_name, :role, :note, :created

      def initialize(password = nil)
        @id = nil
        @name = nil
        @pretty_name = nil
        @masks = []
        @role = nil
        @role_name = nil
        @note = nil
        @created = nil
        @password = nil
      end

      def password?(plaintext_password)
        encrypted_password = BCrypt::Password.new(@password)
        return (encrypted_password == plaintext_password)
      end

      def password_set?()
        return (!@password.nil? && !@password.empty?)
      end

      def set_password(encrypted_password)
        @password = encrypted_password
      end

      def pretty_name_with_color()
        return "#{@role.color}#{@pretty_name}#{Color.reset}"
      end

      def self.from_model(user_model)
        user = new
        user.masks = []
        user.id = user_model.id
        user.name = user_model.name
        user.note = user_model.note
        user.created = user_model.created
        user.pretty_name = user_model.pretty_name
        user_model.masks.each do |mask|
          user.masks.push(mask.mask)
        end
        user.set_password(user_model.password)
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
