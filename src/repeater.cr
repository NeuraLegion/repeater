require "amqp-client"
require "logger"
require "json"

require "./repeater/**"

module Repeater
  VERSION = "0.1.0"
end

# Setup Logger
logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

# Setup RequestExecutor
request_executor = Repeater::RequestExecutor.new(logger)

# Setup and Run the QueueHandler
queue_handler = Repeater::QueueHandler.new(logger, request_executor)
spawn queue_handler.run

while queue_handler.running
  sleep 1
end

Signal::INT.trap do
  exit
end

at_exit do
  logger.info("Closing handler")
  queue_handler.running = false
end
