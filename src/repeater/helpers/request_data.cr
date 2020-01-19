require "json"

module Repeater
  class RequestData
    include JSON::Serializable

    getter :method
    getter :url
    getter :headers
    getter :body

    def initialize(@method : String, @url : String, @headers : Hash(String, String | Array(String)), @body : String?)
    end
  end
end
