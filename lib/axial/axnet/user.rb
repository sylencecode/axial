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

      def match_mask?(in_mask)
        match = false
        @masks.each do |mask|
          mask_regexp = Axial::MaskUtils.get_mask_regexp(mask)
          if (mask_regexp.match(in_mask))
            match = true
            break
          end
        end
        return match
      end

      def bot?()
        if (@role.casecmp('bot').zero?)
          return true
        else
          return false
        end
      end

      def director?()
        if (@role.casecmp('director').zero?)
          return true
        else
          return false
        end
      end

      def manager?()
        if (@role.casecmp('director').zero?)
          return true
        elsif (@role.casecmp('manager').zero?)
          return true
        else
          return false
        end
      end

      def op?()
        if (@role.casecmp('director').zero?)
          return true
        elsif (@role.casecmp('manager').zero?)
          return true
        elsif (@role.casecmp('op').zero?)
          return true
        else
          return false
        end
      end

      def friend?()
        if (@role.casecmp('director').zero?)
          return true
        elsif (@role.casecmp('manager').zero?)
          return true
        elsif (@role.casecmp('op').zero?)
          return true
        elsif (@role.casecmp('friend').zero?)
          return true
        else
          return false
        end
      end
    end
  end
end
