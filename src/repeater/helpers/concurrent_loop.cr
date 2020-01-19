module ConcurrentLoop
  @concurrency = ENV["CRYSTAL_WORKERS"]?.try(&.to_i?) || 4

  protected def concurrent_loop(concurrency : Int = @concurrency, sleep_between : Time::Span? = nil, &block)
    concurrency.times do
      spawn do
        loop do
          block.call
          sleep_between.try { |span| sleep span }
        end
      end
    end
  end
end
