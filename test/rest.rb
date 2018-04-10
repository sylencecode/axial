#!/usr/bin/env ruby
#
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../lib')))
require 'axial/models/init'
require 'axial/models/user'
require 'axial/models/mask'

require 'json'
require 'sinatra/base'

module Axial
  class WebApp < Sinatra::Base
    set :port, 4444
    configure :production, :development do
      enable :logging
    end
    get '/users' do
      response['Access-Control-Allow-Origin'] = '*'
      dump_user_json
    end

    def dump_user_json()
      users = []
      Models::User.all.each do |user|
        if (user.name.downcase == 'unknown')
          next
        end

        hash = {}
        hash['id'] = user.id
        hash['name'] = user.name
        hash['pretty_name'] = user.pretty_name
        hash['created'] = user.created
        hash['note'] = user.note || ''
        hash['masks'] = []
        hash['role_name'] = user.role_name
        user.masks.each do |mask|
          hash['masks'].push mask.to_hash
        end
        if (!user.seen.nil?)
          hash['seen'] = user.seen.to_hash
        else
          hash['seen'] = {}
        end
        users.push(hash)
      end
      return users.to_json
    end
  end
end

Axial::WebApp.run!
