struct HTTP::Headers
  private def check_invalid_header_content(value)
    # Lets not :)
  end
end

class HTTP::Client::Response
  property total_time = Time::Span.zero
end

class HTTP::Client
  private def exec_internal_single(request)
    start_time = Time.monotonic
    previous_def.tap do |response|
      response.try(&.total_time = Time.monotonic - start_time)
    end
  end

  private def exec_internal_single(request)
    start_time = Time.monotonic
    previous_def do |response|
      response.try(&.total_time = Time.monotonic - start_time)
      yield response
    end
  end
end
