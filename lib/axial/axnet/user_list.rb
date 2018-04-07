require 'axial/axnet/user'
require 'axial/mask_utils'

class UserListError < StandardError
end

module Axial
  module Axnet
    class UserList
      attr_reader :monitor

      def initialize()
        @user_list = []
        @monitor = Monitor.new
      end

      def all_users()
        return @user_list.clone
      end

      def count()
        return @user_list.count
      end

      def length()
        return @user_list.count
      end

      def add(new_user)
        if (!new_user.is_a?(Axnet::User))
          raise(AxnetError, "attempted to add an object of type other than Axnet::User: #{new_user.inspect}")
        end
        @monitor.synchronize do
          @user_list.push(new_user)
        end
      end

      def delete(user_name)
        @user_list.delete_if{ |tmp_user| tmp_user.name.casecmp(user_name).zero? }
      end

      def include?(user_name)
        return @user_list.select{ |tmp_user| tmp_user.name.casecmp(user_name).zero? }.any?
      end

      def get_from_name(user_name)
        return @user_list.select{ |tmp_user| tmp_user.name.casecmp(user_name) }.first
      end

      def get_from_nick_object(nick)
        if (!nick.kind_of?(IRCTypes::Nick))
          raise(UserObjectError, "Attempted to query a user record for an object type other than IRCTypes::Nick.")
        end

        user = get_user_from_mask(nick.uhost)
        return user
      end

      def get_user_from_mask(in_mask)
        in_mask = MaskUtils.ensure_wildcard(in_mask)
        possible_users = get_users_from_mask(in_mask)
        if (possible_users.count > 1)
          raise(AxnetError, "mask #{in_mask} returns more than one user: #{possible_users.collect{ |user| user.pretty_name} .join(', ')}")
        end
        return possible_users.uniq.first
      end

      def get_users_from_mask(in_mask)
        possible_users = []
        @monitor.synchronize do
          @user_list.each do |user|
            user.masks.each do |mask|
              if (MaskUtils.masks_match?(mask, in_mask))
                possible_users.push(user)
              end
            end
          end
        end
        return possible_users.uniq
      end

      def get_users_from_overlap(in_mask)
        possible_users = []
        @monitor.synchronize do
          @user_list.each do |user|
            user.masks.each do |mask|
              if (MaskUtils.masks_overlap?(mask, in_mask))
                possible_users.push(user)
              end
            end
          end
        end
        return possible_users.uniq
      end

      def reload(user_list)
        if (!user_list.is_a?(Axnet::UserList))
          raise(AxnetError, "attempted to add an object of type other than Axnet::UserList: #{user_list.inspect}")
        end
        @monitor.synchronize do
          @user_list.clear
          user_list.all_users.each do |user|
            @user_list.push(user)
          end
        end
      end
    end
  end
end
