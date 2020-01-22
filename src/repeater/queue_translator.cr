module Repeater
  module QueueTranslator
    extend self

    def request_from_message(message : AMQP::Client::Message) : HTTP::Request
      request_data = RequestData.from_json(message.body_io.to_s)
      headers = HTTP::Headers.new
      request_data.headers.each do |name, value|
        headers[name] = value
      end
      HTTP::Request.new(
        method: request_data.method,
        resource: request_data.url,
        headers: headers,
        body: request_data.body
      )
    end

    def response_to_message(response : HTTP::Client::Response) : String
      headers = Hash(String, Array(String)).new
      response.headers.each do |name, value|
        headers[name] = value
      end
      ResponseData.new(
        status_code: response.status_code,
        headers: headers,
        body: response.body.to_s
      ).to_json
    end
  end
end
