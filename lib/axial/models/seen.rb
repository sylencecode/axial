gem 'sequel'
require 'sequel'
require 'axial/models/init'
require 'axial/models/user'

module Axial
  module Models
    class Seen < Sequel::Model
      many_to_one :user
    end

    # remember to run self.something.update instead of save and such
  end
end
