gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'

module Axial
  module API
    module Yandex
      module V15
        class TRJson
          @yandex_rest_api  = 'https://translate.yandex.net/api/v1.5/tr.json'
          @yandex_api_key   = 'trnsl.1.1.20180314T084321Z.c3f04388a321a97b.b8f41a8ad142ad694845236e1af9e9e1eaad6fab'

          def self.default_headers()
            headers = {
                accept: 'application/json'
            }
            return headers
          end

          def self.default_params()
            params = {
                key: @yandex_api_key
            }

            return params
          end

          def self.translate(source_language, target_language, source_text)
            rest_endpoint   = URI.parse(@yandex_rest_api + '/translate')
            headers         = default_headers
            params          = default_params
            params[:lang]   = "#{source_language}-#{target_language}"
            payload         = 'text=' + source_text

            rest_endpoint.query = URI.encode_www_form(params)
            json = RestClient::Request.execute(method: :post, headers: headers, payload: payload, url: rest_endpoint.to_s, verify_ssl: false)
            json_hash = JSON.parse(json)

            target_text_array = json_hash.dig('text')
            if (target_text_array.nil? || !target_text_array.is_a?(Array) || target_text_array.empty?)
              translation = nil
            else
              target_text = target_text_array.first
              translation = Yandex::TranslationResult.new(source_language, source_text, target_language, target_text)
            end

            return translation
          rescue RestClient::Exception => ex
            LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
            return nil
          end

          def self.detect(text)
            rest_endpoint   = URI.parse(@yandex_rest_api + '/detect')
            headers         = default_headers
            params          = URI.encode_www_form(default_params)
            payload         = 'text=' + text

            rest_endpoint.query = params
            json = RestClient::Request.execute(method: :post, headers: headers, payload: payload, url: rest_endpoint.to_s, verify_ssl: false)
            json_hash = JSON.parse(json)

            detected_language = json_hash.dig('lang')
            return detected_language
          rescue RestClient::Exception => ex
            LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
            return nil
          end
        end
      end
    end
  end
end
