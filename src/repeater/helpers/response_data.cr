require "json"

module Repeater
  class ResponseData
    include JSON::Serializable

    getter status_code : Int32
    getter headers : Hash(String, Array(String))
    getter body : String?

    def initialize(@status_code, @headers, @body)
    end

    def to_http : ::HTTP::Client::Response
      http_headers = ::HTTP::Headers.new
      @headers.each { |name, value| http_headers[name] = value }
      ::HTTP::Client::Response.new(
        status_code: @status_code,
        headers: http_headers,
        body: @body
      )
    end
  end
end
