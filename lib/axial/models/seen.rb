gem 'sequel'
require 'sequel'
require 'axial/models/init'
require 'axial/models/user'

module Axial
  module Models
    class Seen < Sequel::Model
      many_to_one :user

      def self.delete_or_unknown(user_id)
        unknown_user = Models::User[name: 'unknown']
        if (!unknown_user.nil?)
          unknown_user_id = unknown_user.id
        else
          unknown_user_id = 0
        end

        if (!DB_CONNECTION[:seens].nil?)
          if (unknown_user_id.zero?)
            DB_CONNECTION[:seens].where(user_id: user_id).delete
          else
            DB_CONNECTION[:seens].where(user_id: user_id).update(user_id: unknown_user_id)
          end
        end
      end

      def self.upsert(user, last, status)
        if (!user.kind_of?(Models::User))
          raise(UserObjectError, "#{self.class}.upsert requires a Models::User object")
        end
        if (!last.kind_of?(Time))
          raise(UserObjectError, "#{self.class}.upsert requires a Time object")
        end
        if (status.nil? || status.empty?)
          status = 'for the first time'
        end

        seen = self[user_id: user.id]
        if (seen.nil?)
          self.create(user_id: user.id, last: last, status: status)
        else
          seen.update(last: last, status: status)
        end
        return seen
      end
    end
  end
end
