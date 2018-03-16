gem 'sequel'
require 'sequel'
require 'models/user.rb'

class ThingError < StandardError
end

module Axial
  module Models
    class Thing < Sequel::Model
      many_to_one :user

      def self.upsert(thing, explanation, user_model)
        if (!user_model.kind_of?(Models::User))
          raise(UserObjectError, "#{self.class}.upsert requires a Models::User object")
        end
        thing_model = self[thing: thing.downcase]
        if (thing_model.nil?)
          self.create(thing: thing.downcase, pretty_thing: thing, explanation: explanation, user_id: user_model[:id], learned_at: Time.now)
        else
          thing_model.thing = thing.downcase
          thing_model.update(pretty_thing: thing, explanation: explanation, user_id: user_model[:id], learned_at: Time.now)
        end
        return thing_model
      end
    end
  end
end
