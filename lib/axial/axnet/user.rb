module Axial
  module Axnet
    class User
      attr_accessor :id, :name, :pretty_name, :masks, :role_name
      def initialize()
        @id = nil
        @name = nil
        @pretty_name = nil
        @masks = []
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

      def bot?()
        if (@role_name.casecmp('bot').zero?)
          return true
        else
          return false
        end
      end

      def director?()
        if (@role_name.casecmp('director').zero?)
          return true
        else
          return false
        end
      end

      def manager?()
        if (@role_name.casecmp('director').zero?)
          return true
        elsif (@role_name.casecmp('manager').zero?)
          return true
        else
          return false
        end
      end

      def op?()
        if (@role_name.casecmp('director').zero?)
          return true
        elsif (@role_name.casecmp('manager').zero?)
          return true
        elsif (@role_name.casecmp('op').zero?)
          return true
        else
          return false
        end
      end

      def friend?()
        if (@role_name.casecmp('director').zero?)
          return true
        elsif (@role_name.casecmp('manager').zero?)
          return true
        elsif (@role_name.casecmp('op').zero?)
          return true
        elsif (@role_name.casecmp('friend').zero?)
          return true
        else
          return false
        end
      end
    end
  end
end
