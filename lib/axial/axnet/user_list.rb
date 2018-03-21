require 'axial/axnet/user'

class UserListError < StandardError
end

module Axial
  module Axnet
    class UserList
      def initialize()
        @users = []
      end

      def add(user)
        if (!user.is_a?(Axnet::User))
          raise(UserListError, "attempted to add an object of type other than Axnet::User: #{user.inspect}")
        end
        @users.push(user)
      end
    end
  end
end
