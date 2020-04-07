require "amqp-client"

module Repeater
  class QueueHandler
    property running : Bool = true

    @client : AMQP::Client
    @connection_string : String

    def initialize(@logger : Logger, @request_executor : RequestExecutor)
      @logger.debug("QueueHandler Initalized")
      @lock = Mutex.new
      @connection_string = "amqps://#{ENV["AGENT_ID"]}:#{ENV["AGENT_KEY"]}@#{ENV["NEXPLOIT_DOMAIN"]? || "amq.nexploit.app"}:5672"
      @client = AMQP::Client.new(url: @connection_string, frame_max: UInt32::Max)
    end

    def run
      @logger.info("Connecting to #{@connection_string}")
      requests_connection = @client.connect
      response_connection = @client.connect

      requests_connection.on_close do
        @logger.info("requests_connection closed, reconnecting!")
        requests_connection = @client.connect
      end

      response_connection.on_close do
        @logger.info("response_connection closed, reconnecting!")
        response_connection = @client.connect
      end

      request_queue = requests_connection.channel.queue("agents:#{ENV["AGENT_ID"]}:requests")
      response_queue = response_connection.channel.queue("agents:#{ENV["AGENT_ID"]}:responses")

      loop do
        break unless running
        begin
          request_queue.subscribe(no_ack: true, block: true) do |msg|
            @logger.debug("Received: #{msg.body_io.to_s}")
            spawn do
              message_handler(message: msg, queue: response_queue)
            end
          end
        rescue e : Exception
          @logger.error("Error in subscribe loop: #{e.inspect_with_backtrace}")
        end
      end
    end

    def message_handler(message : AMQP::Client::Message, queue : AMQP::Client::Queue)
      # Translate request from message string
      request = QueueTranslator.request_from_message(message)
      @logger.debug("Parsed request: #{request.inspect}")
      # Execute the request
      begin
        response = @request_executor.exec(
          method: request.method,
          path: request.resource,
          headers: request.headers,
          body: request.body.to_s
        )
      rescue e : Exception
        response = HTTP::Client::Response.new(500)
      end
      # Translate the response to message (which will be sent to the queue)
      response_message = QueueTranslator.response_to_message(response)
      # Send to queue
      @logger.debug("Sending: #{response_message}")
      queue.publish(response_message)
    rescue e : Exception
      @logger.error("Error handling message: #{e.inspect_with_backtrace}")
    end
  end
end
