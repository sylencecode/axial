gem 'rest-client'
require 'rest-client'
require 'uri'
require 'json'

$yandex_api_key = 'trnsl.1.1.20180314T084321Z.c3f04388a321a97b.b8f41a8ad142ad694845236e1af9e9e1eaad6fab'

module Axial
  module API
    module Yandex
      module V1_5
        class TRJson
          @yandex_rest_api   = 'https://translate.yandex.net/api/v1.5/tr.json'

          def self.translate(source_language, target_language, text)
            rest_endpoint = URI.parse(@yandex_rest_api + '/translate')

            headers = {
              accept: 'application/json'
            }

            params = {
                lang: "#{source_language}-#{target_language}",
                 key: $yandex_api_key
            }

            rest_endpoint.query  = URI.encode_www_form(params)

            payload = 'text=' + text

            response = RestClient::Request.execute(method: :post, headers: headers, payload: payload, url: rest_endpoint.to_s, verify_ssl: false)
            json = JSON.parse(response)

            translation = nil
            if (json.key?('text'))
              text = json['text']
              if (text.is_a?(Array) && text.count > 0)
                translation = text.first
              end
            end
            return translation
          rescue RestClient::Exception => ex
            LOGGER.error("#{self.class} error: #{ex.class}: #{ex.message}")
            return nil
          end

          def self.detect(text)
            rest_endpoint = URI.parse(@yandex_rest_api + '/detect')

            headers = {
              accept: 'application/json'
            }

            params = {
              key: $yandex_api_key
            }

            rest_endpoint.query  = URI.encode_www_form(params)

            payload = 'text=' + text

            response = RestClient::Request.execute(method: :post, headers: headers, payload: payload, url: rest_endpoint.to_s, verify_ssl: false)
            json = JSON.parse(response)

            detected_language = nil
            if (json.key?('lang'))
              lang = json['lang']
              if (lang.is_a?(String) && !lang.empty?)
                detected_language = lang
              end
            end
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
