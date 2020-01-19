module Repeater
  class QueueHandler
    def initialize(@logger : Logger, @request_executor : RequestExecutor)
    end

    def run
      AMQP::Client.start("amqp://#{ENV["AGENT_ID"]}:#{ENV["AGENT_KEY"]}@#{ENV["NEXPLOIT_DOMAIN"]? || "queue.nexploit.app"}") do |client|
        client.channel do |channel|
          queue = channel.queue("#{ENV["AGENT_ID"]}")
          queue.subscribe(no_ack: false) do |msg|
            @logger.debug("Received: #{msg.body_io.to_s}")
            channel.basic_ack(msg.delivery_tag)
            spawn { message_handler(message: msg, queue: queue) }
          end
        end
      end
    end

    def message_handler(message : AMQP::Client::Message, queue : AMQP::Client::Queue)
      # Translate request from message string
      request = QueueTranslator.request_from_message(message)
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
      queue.publish_confirm(response_message)
    end
  end
end
