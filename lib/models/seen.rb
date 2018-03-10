#!/usr/bin/env ruby

require 'sequel'

module Axial
  module Models
    class Seen < Sequel::Model
      many_to_one :nick
    end
  end
end
