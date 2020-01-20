require "logger"
require "./spec_helper"

describe Repeater::QueueHandler do
  it "execute request over queue" do
    logger = Logger.new(STDOUT)
    logger.level = Logger::DEBUG

    spawn do
      request_executor = Repeater::RequestExecutor.new(logger)
      handler = Repeater::QueueHandler.new(logger, request_executor)
      handler.run
    end

    logger.debug("Spec handler running")

    AMQP::Client.start("amqp://#{ENV["AGENT_ID"]}:#{ENV["AGENT_KEY"]}@#{ENV["NEXPLOIT_DOMAIN"]? || "queue.nexploit.app"}") do |client|
      client.channel do |channel|
        request_queue = channel.queue("requests")
        response_queue = channel.queue("responses")

        message = <<-EOF
        {
          "method": "GET",
          "url": "https://www.google.com",
          "headers": {
            "User-Agent": "NexPloit On-Prem Agent"
          }
        }
        EOF
        request_queue.publish(message)

        logger.debug("spec subscribing")

        response_queue.subscribe(no_ack: false, block: true) do |msg|
          logger.info("Spec got back answer from agent")
          channel.basic_ack(msg.delivery_tag)
          r_data = Repeater::ResponseData.from_json(msg.body_io.to_s)
          logger.debug("Got back: #{r_data.inspect}")
        end
      end
    end
  end
end
