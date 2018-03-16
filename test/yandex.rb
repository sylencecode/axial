#!/usr/bin/env ruby

gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'

@rest_api     = 'https://translate.yandex.net/api/v1.5/tr.json/translate'
@yandex_api_key = 'trnsl.1.1.20180314T084321Z.c3f04388a321a97b.b8f41a8ad142ad694845236e1af9e9e1eaad6fab'


            rest_endpoint = URI.parse(@rest_api)
        
            params = {
                lang: 'en-es',
                 key: @yandex_api_key
            }
            rest_endpoint.query  = URI.encode_www_form(params)
        
#            headers = {
#              content_type: 'application/json',
#                    accept: 'application/json'
#            }
        
            payload = "text=hello, ny name is robert"
            RestClient.log = 'stdout'
            response = RestClient.post(rest_endpoint.to_s, payload)
            #response = RestClient.post(rest_endpoint.to_s, payload.to_json, headers)
            json = JSON.parse(response)
      puts JSON.pretty_generate(json)

#      params[:key]    = @yandex_api_key
#      params[:text]    = "once upon a time, there was a man"
#      params[:lang]    = "en-es"

 #     uri = URI::parse(@rest_api)
 #     uri.query = URI.encode_www_form(params)
 #     response = RestClient.get(uri.to_s)
 #     json = JSON.parse(response)
      #puts JSON.pretty_generate(json)
