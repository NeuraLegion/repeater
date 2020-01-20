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
queue_handler.run
sleep
