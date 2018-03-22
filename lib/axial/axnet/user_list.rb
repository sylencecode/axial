require 'axial/axnet/user'

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
        @user_list.push(new_user)
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

      def some_read_op()
        @monitor.synchronize do
        end
      end
    end
  end
end
