#!/usr/bin/env ruby

require 'sequel'

module Axial
  module Models
    class Seen < Sequel::Model
      many_to_one :nick
    end

    # remember to run self.something.update instead of save and such
  end
end
