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
    end
  end
end
