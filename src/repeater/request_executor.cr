require "http"
require "./helpers/**"

module Repeater
  class RequestExecutor
    include ConcurrentLoop
    include Synchronizable

    Log = Repeater::Log.for("RequestExecuter")
    # For HTTP
    alias RequestData = NamedTuple(
      method: String,
      path: String,
      headers: ::HTTP::Headers?,
      body: ::HTTP::Client::BodyType?,
      channel: Channel(ResponseData),
    )
    alias ResponseData = ::HTTP::Client::Response | Exception | IO::TimeoutError | IO::Error

    # For WebSockets
    alias WSRequestData = NamedTuple(
      path: String,
      headers: ::HTTP::Headers,
      body: String,
      channel: Channel(WSResponseData),
    )
    alias WSResponseData = String | Exception | IO::TimeoutError | IO::Error

    @http_waiting_for_answer : Atomic(Int64)
    @ws_waiting_for_answer : Atomic(Int64)
    @ch : Channel(RequestData)
    @ws_ch : Channel(WSRequestData)
    @ctx : OpenSSL::SSL::Context::Client
    @timeout : Time::Span
    @name : String

    getter :timeout

    def initialize(
      @concurrency = 50,
      @timeout = 120.seconds,
      @name = "RequestExecutor"
    )
      # For HTTP
      @ch = Channel(RequestData).new
      @http_waiting_for_answer = Atomic(Int64).new(0)

      # For WebSockets
      @ws_ch = Channel(WSRequestData).new
      @ws_waiting_for_answer = Atomic(Int64).new(0)

      # SSL Configurations
      @ctx = OpenSSL::SSL::Context::Client.new
      @ctx.verify_mode = :none
      @ctx.ciphers = "ALL"
      @ctx.add_options(:all)

      concurrent_loop { executor }
      concurrent_loop { ws_executor }

      # Log status of the executor, requests, channels and cookies
      concurrent_loop(concurrency: 1, sleep_between: 1.minute) { log_status }
    end

    private def executor
      data = @ch.receive

      uri = URI.parse(data[:path])

      # Set request object for logging
      body = data[:body]
      headers = data[:headers]

      req = ::HTTP::Request.new(data[:method], uri.full_path, headers, body)

      ::HTTP::Client.new(
        host: uri.host.to_s,
        port: uri.port,
        tls: (uri.scheme == "https" ? @ctx : false)
      ) do |client|
        # Set Timeouts
        client.read_timeout = @timeout
        client.write_timeout = @timeout
        client.dns_timeout = @timeout
        client.connect_timeout = @timeout

        client.before_request do |request|
          req = request
        end

        # Execute request
        response = client.exec(data[:method], uri.full_path, headers, body)

        # Send back response to queue
        data[:channel].send response

        # Log final Request
        Log.debug { "Executor sent: #{req.inspect} @body: #{body}" }
        # Log final Response
        Log.debug { "Executor received: #{response.inspect}" }
      end
    rescue e : IO::TimeoutError
      data[:channel].send e if data
      Log.error(exception: e) { "Error executing request: #{e.inspect_with_backtrace}" }
      Log.debug { "Failed executing: #{req.inspect}" }
    rescue e : IO::Error
      data[:channel].send e if data
      Log.error(exception: e) { "Error executing request: #{e.inspect_with_backtrace}" }
      Log.debug { "Failed executing: #{req.inspect}" }
    rescue e : Exception
      data[:channel].send e if data
      Log.error(exception: e) { "Error executing request: #{e.inspect_with_backtrace}" }
      Log.debug { "Failed executing: #{req.inspect}" }
    end

    private def ws_executor
      data = @ws_ch.receive
      begin
        uri = URI.parse(data[:path])

        # Make sure to properly encode the URI
        uri.query = ::HTTP::Params.parse(uri.query.to_s).to_s

        headers = data[:headers]

        tls = (uri.scheme == "wss" || uri.scheme == "https")
        # WebSockets don't support context yet
        ws = ::HTTP::WebSocket.new(
          host: uri.host.to_s,
          path: uri.path,
          tls: tls ? @ctx : nil,
          headers: headers
        )
        received = nil
        ws.on_message do |message|
          # Send back response to queue
          received = message
          data[:channel].send message
          ws.close
        end

        ws.send(data[:body])
        spawn ws.run

        @timeout.total_seconds.to_i.times do
          break if received
          sleep 1.second
        end
        raise IO::TimeoutError.new("Timeout while waiting for WebSocket to respond") unless received

        # Log final Request
        Log.debug { "Executor WebSocket sent: #{data[:body]}" }
        # Log final Response
        Log.debug { "Executor received: #{received}" }
      rescue e : IO::TimeoutError
        data[:channel].send e
        Log.error(exception: e) { "Error executing request: #{e.inspect_with_backtrace}" }
      rescue e : IO::Error
        data[:channel].send e
        Log.error(exception: e) { "Error executing request: #{e.inspect_with_backtrace}" }
      rescue e : Exception
        data[:channel].send e
        Log.error(exception: e) { "Error executing request: #{e.inspect_with_backtrace}" }
      end
    end

    def exec(method : String, path : String, headers : ::HTTP::Headers? = nil, body : ::HTTP::Client::BodyType? = nil) : ::HTTP::Client::Response
      track_waiting do
        channel = Channel(ResponseData).new(1)
        @ch.send({
          method:  method,
          path:    path,
          headers: headers,
          body:    body,
          channel: channel,
        })
        case resp = channel.receive
        when ::HTTP::Client::Response then resp
        when Exception                then raise resp
        when IO::TimeoutError         then raise resp
        when IO::Error                then raise resp
        else
          raise "Unknown response type! #{resp} #{resp.class}"
        end
      end
    end

    def exec_ws(path : String, headers : ::HTTP::Headers, body : String) : String
      track_waiting do
        channel = Channel(WSResponseData).new(1)
        @ws_ch.send({
          path:    path,
          headers: headers,
          body:    body,
          channel: channel,
        })
        case resp = channel.receive
        when String           then resp
        when Exception        then raise resp
        when IO::TimeoutError then raise resp
        when IO::Error        then raise resp
        else
          raise "Unknown response type! #{resp} (#{resp.class})"
        end
      end
    end

    private def log_status
      Log.debug { "#{@name} status summary" }
      Log.debug { "HTTP fibers waiting for response: #{@http_waiting_for_answer.get}" }
      Log.debug { "WebSocket fibers waiting for response: #{@ws_waiting_for_answer.get}" }
    end

    private def track_waiting
      wait
      yield
    ensure
      unwait
    end

    private def wait
      @http_waiting_for_answer.add(1)
    end

    private def unwait
      @http_waiting_for_answer.sub(1)
    end
  end
end
