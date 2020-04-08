require "amqp-client"

module Repeater
  class QueueHandler
    Log = Repeater::Log.for("QueueHandler")

    property running : Bool = true

    @client : AMQP::Client

    def initialize(@request_executor : RequestExecutor)
      Log.debug { "QueueHandler Initalized" }
      @lock = Mutex.new
      @client = AMQP::Client.new(
        host: ENV["NEXPLOIT_DOMAIN"]? || "amq.nexploit.app",
        frame_max: UInt32::MAX,
        port: 5672,
        user: ENV["AGENT_ID"],
        password: ENV["AGENT_KEY"],
        tls: true
      )
    end

    def run
      Log.info { "Connecting to #{ENV["NEXPLOIT_DOMAIN"]? || "amq.nexploit.app"}:5672" }
      requests_connection = @client.connect
      response_connection = @client.connect

      requests_connection.on_close do
        Log.info { "requests_connection closed, reconnecting!" }
        requests_connection = @client.connect
      end

      response_connection.on_close do
        Log.info { "response_connection closed, reconnecting!" }
        response_connection = @client.connect
      end

      request_queue = requests_connection.channel.queue("agents:#{ENV["AGENT_ID"]}:requests")

      loop do
        break unless running
        begin
          request_queue.subscribe(no_ack: true, block: true) do |msg|
            Log.debug { "Received: #{msg.body_io.to_s}" }
            spawn do
              response_queue = response_connection.channel.queue("agents:#{ENV["AGENT_ID"]}:responses")
              message_handler(message: msg, queue: response_queue)
            end
          end
        rescue e : Exception
          Log.error { "Error in subscribe loop: #{e.inspect_with_backtrace}" }
        end
      end
    end

    def message_handler(message : AMQP::Client::Message, queue : AMQP::Client::Queue)
      # Translate request from message string
      request = QueueTranslator.request_from_message(message)
      Log.debug { "Parsed request: #{request.inspect}" }
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
      Log.debug { "Sending: #{response_message} with correlation_id: #{message.properties.correlation_id}" }
      queue.publish(
        message: response_message,
        props: AMQ::Protocol::Properties.new(
          correlation_id: message.properties.correlation_id
        )
      )
    rescue e : Exception
      Log.error(exception: e) { "Error handling message: #{e.inspect_with_backtrace}" }
    end
  end
end
