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
          raise(AxnetError, "attempted to add an object of type other than Axnet::User: #{user_list.inspect}")
        end
        @monitor.synchronize do
          @user_list.push(new_user)
        end
      end

      def get_from_nick_object(nick)
        if (!nick.kind_of?(IRCTypes::Nick))
          raise(UserObjectError, "Attempted to query a user record for an object type other than Axial::IRCTypes::Nick.")
        end

        user = get_user_from_mask(nick.uhost)
        return user
      end

      def get_user_from_mask(in_mask)
        in_mask = Axial::MaskUtils.ensure_wildcard(in_mask)
        possible_users = get_users_from_mask(in_mask)
        if (possible_users.count > 1)
          raise(AxnetError, "mask #{in_mask} returns more than one user: #{possible_users.collect{ |user| user.pretty_name} .join(', ')}")
        end
        return possible_users.first
      end

      def get_users_from_mask(in_mask)
        possible_users = []
        @monitor.synchronize do
          left_mask = Axial::MaskUtils.ensure_wildcard(in_mask)
          left_regexp = Axial::MaskUtils.get_mask_regexp(in_mask)
          @user_list.each do |user|
            user.masks.each do |right_mask|
              right_regexp = Axial::MaskUtils.get_mask_regexp(right_mask)
              if (right_regexp.match(left_mask))
                possible_users.push(user)
              elsif (left_regexp.match(right_mask))
                possible_users.push(user)
              end
            end
          end
        end
        return possible_users
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
