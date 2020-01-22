require "amqp-client"

module Repeater
  class QueueHandler
    getter running : Bool = true

    def initialize(@logger : Logger, @request_executor : RequestExecutor)
      @logger.debug("QueueHandler Initalized")
    end

    def run
      # Setup Client
      @logger.debug("QueueHandler subscribing to queue")
      loop do
        @logger.debug("Looping")
        sleep 0.1
        Fiber.yield
        begin
          client = AMQP::Client.new("amqp://#{ENV["AGENT_ID"]}:#{ENV["AGENT_KEY"]}@#{ENV["NEXPLOIT_DOMAIN"]? || "queue.nexploit.app"}")
          connection = client.connect
          channel = connection.channel
          request_queue = channel.queue("requests")
          response_queue = channel.queue("responses")
          request_queue.subscribe(no_ack: true, block: true) do |msg|
            @logger.debug("Received: #{msg.body_io.to_s}")
            # channel.basic_ack(msg.delivery_tag)
            spawn do
              message_handler(message: msg, queue: response_queue)
            end
          end
        rescue e : Exception
          @logger.error("Error in subscribe loop: #{e.inspect_with_backtrace}")
        ensure
          connection.try &.close
        end
      end
      @logger.info("Connection closed! loop broken")
      @running = false
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
