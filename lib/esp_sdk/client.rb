require 'rest_client'

module EspSdk
  class Client
    attr_reader :config, :errors

    def initialize(config)
      @config  = config
    end

    def connect(url, type=:get, payload={})
      headers = { 'Authorization' => @config.token, 'Authorization-Email' => @config.email, 'Content-Type' => 'json/text' }
      payload = { self.class.to_s.demodulize.singularize.underscore => payload } if payload.present?
      begin
        if type == :get || type == :delete
          if payload.present?
            response = RestClient.send(type, url, headers.merge(params: payload))
          else
            response = RestClient.send(type, url, headers)
          end
        else
          response = RestClient.send(type, url, payload, headers)
        end
      rescue RestClient::UnprocessableEntity, RestClient::Unauthorized => e
        response = e.response
        body     = Client.convert_json(response.body)
        @errors  = body['errors'] if body.present? && body.kind_of?(Hash) && body['errors'].present?
      end

      if @errors.present?
        if @errors.select { |error| error.to_s.include?('Token has expired') }.present?
          raise EspSdk::Exceptions::TokenExpired, 'Token has expired'
        elsif (error = @errors.select { |error| error.to_s.include?('Record not found') }[0]).present?
          raise EspSdk::Exceptions::RecordNotFound, error
        end
      end

      response
    end

    # Recursively convert json
    def self.convert_json(json)
      if json.is_a?(String)
        begin
          convert_json(JSON.load(json))
        rescue JSON::ParserError
          # Rescue a parse error and return the object.
          json
        end
      elsif json.is_a?(Array)
        json.each_with_index do |value, index|
          json[index] = convert_json(value)
        end
      else
        if json.is_a?(Array)
          json
        else
          ActiveSupport::HashWithIndifferentAccess.new(json)
        end
      end
    end
  end
end
