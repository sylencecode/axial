gem 'sequel'
require 'sequel'
require 'axial/role'
require 'axial/irc_types/nick'
require 'axial/mask_utils'
require 'axial/models/init'
require 'axial/models/mask'
require 'axial/models/seen'

class DuplicateUserError < DatabaseError
end

class UserObjectError < DatabaseError
end

module Axial
  module Models

    # note to self: you can use this if your model does not directly imply a table
    # User = Class.new(Sequel::Model)
    # class User
    #  set_dataset :nicks
    class User < Sequel::Model
      attr_reader :role

      one_to_many :masks
      one_to_many :things
      one_to_many :rss_feeds
      one_to_many :bans
      one_to_one  :seen

      def possible_masks()
        res = []
        masks.each do |result|
          res.push(result.mask)
        end
        res
      end

      def after_initialize()
        @role = Role.new(@role_name)
      end

      def role=(role)
        if (!role.is_a?(Role))
          raise(UserObjectError, "#{self.class}.role= called with a type other than Axial::Role")
        end

        @role = role
        self.update(role_name: role.name)
      end

      def self.get_from_nick_object(nick)
        if (!nick.kind_of?(IRCTypes::Nick))
          raise(UserObjectError, "Attempted to query a user record for an object type other than IRCTypes::Nick")
        end

        user_model = self[name: nick.name.downcase]
        if (!user_model.nil? && user_model.match_mask?(nick.uhost))
          return user_model
        end
        return nil
      end

      def match_mask?(in_mask)
        match = false
        masks.each do |mask|
          if (MaskUtils.masks_match?(mask.mask, in_mask))
            match = true
            break
          end
        end
        return match
      end

      def self.create_from_nickname_mask(nickname, mask)
        mask = MaskUtils.ensure_wildcard(mask)
        user_model = User.create(name: nickname.downcase, pretty_name: nickname)
        user_model.seen = Seen.create(user_id: user_model.id, status: 'for the first time', last: Time.now)
        mask_model = Models::Mask.create(mask: mask, user_id: user_model.id)
        user_model.add_mask(mask_model)
        return user_model
      end

      def director?()
        if (role_name.casecmp('director').zero?)
          return true
        else
          return false
        end
      end

      def manager?()
        if (role_name.casecmp('director').zero?)
          return true
        elsif (role_name.casecmp('manager').zero?)
          return true
        else
          return false
        end
      end

      def op?()
        if (role_name.casecmp('director').zero?)
          return true
        elsif (role_name.casecmp('manager').zero?)
          return true
        elsif (role_name.casecmp('op').zero?)
          return true
        else
          return false
        end
      end

      def friend?()
        if (role_name.casecmp('director').zero?)
          return true
        elsif (role_name.casecmp('manager').zero?)
          return true
        elsif (role_name.casecmp('op').zero?)
          return true
        elsif (role_name.casecmp('friend').zero?)
          return true
        else
          return false
        end
      end

      def self.get_from_nickname(nickname)
        return self[name: nickname.downcase]
      end
    end
  end
end
