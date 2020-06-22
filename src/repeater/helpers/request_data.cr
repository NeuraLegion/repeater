require "json"

module Repeater
  class RequestData
    include JSON::Serializable

    getter method : String
    getter url : String
    getter headers = Hash(String, Array(String)).new
    getter body : String?

    def initialize(@method, @url, http_headers : ::HTTP::Headers, @body)
      http_headers.each { |name, value| @headers[name] = value }
      if extra_headers = ENV["EXTRA_HEADERS"]?
        Log.debug { "Found extra headers: #{ENV["EXTRA_HEADERS"]?}" }
        Hash(String, String).from_json(extra_headers).tap do |hash|
          hash.each do |key, value|
            @headers[key] = [value]
          end
        end
      end
    end

    def add_headers_from_env
      if extra_headers = ENV["EXTRA_HEADERS"]?
        Log.debug { "Found extra headers: #{ENV["EXTRA_HEADERS"]?}" }
        Hash(String, String).from_json(extra_headers).tap do |hash|
          hash.each do |key, value|
            @headers[key] = [value]
          end
        end
      end
    end

    def self.from_json(string : String)
      klass = super(string)
      klass.add_headers_from_env
      klass
    end
  end
end
