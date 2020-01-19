require "json"

module Repeater
  class ResponseData
    include JSON::Serializable

    getter :status
    getter :headers
    getter :body

    def initialize(@status : Int32, @headers : Hash(String, String | Array(String)), @body : String?)
    end
  end
end
