module Repeater
  class QueueHandler
    def initialize(@logger : Logger, @request_executor : RequestExecutor)
      @logger.debug("QueueHandler Initalized")
    end

    def run
      AMQP::Client.start("amqp://#{ENV["AGENT_ID"]}:#{ENV["AGENT_KEY"]}@#{ENV["NEXPLOIT_DOMAIN"]? || "queue.nexploit.app"}") do |client|
        client.channel do |channel|
          request_queue = channel.queue("requests")
          response_queue = channel.queue("responses")
          @logger.debug("QueueHandler subscribing to queue")
          loop do
            @logger.debug("looping for messages in QueueHandler")
            sleep 1
            channel.basic_consume("responses", no_ack: true, exclusive: false, block: false) do |msg|
              case msg.body_io.to_s
              when "ack"
                channel.basic_ack(msg.delivery_tag)
              when "reject"
                channel.basic_reject(msg.delivery_tag, requeue: true)
              when "nack"
                channel.basic_nack(msg.delivery_tag, requeue: true, multiple: true)
              else
                spawn do
                  message_handler(message: msg, queue: response_queue)
                end
              end
            end
          end
        end
      end
      @logger.info("Handler out of AMQP::Client loop")
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
      queue.publish(response_message)
    end
  end
end
