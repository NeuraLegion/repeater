require "amqp-client"
require "log"
require "json"
require "mt_helpers"
require "./repeater/**"

module Repeater
  VERSION = "0.1.0"
  ::Log.builder.bind("*", :debug, ::Log::IOBackend.new)
  Log = ::Log.for("Repeater")
end

# Setup RequestExecutor
request_executor = Repeater::RequestExecutor.new

# Setup and Run the QueueHandler
queue_handler = Repeater::QueueHandler.new(request_executor)
spawn queue_handler.run

while queue_handler.running
  sleep 1
end

Signal::INT.trap do
  exit
end

at_exit do
  queue_handler.running = false
end
