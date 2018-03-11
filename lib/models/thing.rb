#!/usr/bin/env ruby

require 'sequel'
require 'models/nick.rb'

class RSSError < Exception
end

module Axial
  module Models
    class Thing < Sequel::Model
      many_to_one :nick

      def self.upsert(thing, explanation, nick_model)
        if (!nick_model.kind_of?(Models::Nick))
          raise(NickObjectError, "#{self.class}.upsert requires a Models::Nick object")
        end
        thing_model = self[thing: thing.downcase]
        if (thing_model.nil?)
          self.create(thing: thing.downcase, pretty_thing: thing, explanation: explanation, nick_id: nick_model[:id], learned_at: Time.now)
        else
          thing_model.thing = thing.downcase
          thing_model.update(pretty_thing: thing, explanation: explanation, nick_id: nick_model[:id], learned_at: Time.now)
        end
        return thing_model
      end
    end
  end
end
