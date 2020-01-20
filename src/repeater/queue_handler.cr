require "amqp-client"

module Repeater
  class QueueHandler
    @client : AMQP::Client
    @connection : AMQP::Client::Connection

    def initialize(@logger : Logger, @request_executor : RequestExecutor)
      @logger.debug("QueueHandler Initalized")
      @client = AMQP::Client.new("amqp://#{ENV["AGENT_ID"]}:#{ENV["AGENT_KEY"]}@#{ENV["NEXPLOIT_DOMAIN"]? || "queue.nexploit.app"}")
      @connection = @client.connect
    end

    def run
      # Setup Client
      @logger.debug("Client connected")
      channel = @connection.channel
      request_queue = channel.queue("requests")
      response_queue = channel.queue("responses")

      @logger.debug("QueueHandler subscribing to queue")
      request_queue.subscribe(no_ack: false, block: false) do |msg|
        @logger.debug("Received: #{msg.body_io.to_s}")
        channel.basic_ack(msg.delivery_tag)
        spawn do
          message_handler(message: msg, queue: response_queue)
        end
      end
    end

    def message_handler(message : AMQP::Client::Message, queue : AMQP::Client::Queue)
      # Translate request from message string
      request = QueueTranslator.request_from_message(message)
      @logger.debug("Parsed request: #{request.inspect}")
      # Execute the request
      response = @request_executor.exec(
        method: request.method,
        path: request.resource,
        headers: request.headers,
        body: request.body.to_s
      )
      # Translate the response to message (which will be sent to the queue)
      response_message = QueueTranslator.response_to_message(response)
      # Send to queue
      @logger.debug("Sending: #{response_message}")
      queue.publish_confirm(response_message)
    end
  end
end
