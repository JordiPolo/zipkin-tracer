require 'faraday'
require 'finagle-thrift/tracer'

module Trace
  # This class is a base for tracers sending information to Zipkin.
  # It knows about zipkin types of annotations and send traces when the server
  # is done with its request
  # Traces dealing with zipkin should inherit from this class and implement the
  # flush! method which actually sends the information
  class ZipkinTracerBase < Tracer

    def initialize(options={})
      @options = options
      reset
    end

    def with_new_span(trace_id, name)
      span = start_span(trace_id, name)
      result = yield span
      end_span(span)
      result
    end

    def end_span(span)
      Rails.logger.info("Zipkin: Ending span")
      span.close
      if span.annotations.any?{ |ann| ann.value == Annotation::SERVER_SEND }
        Rails.logger.info("Flushing")
        flush!
        reset
      end
    end

    def start_span(trace_id, name)
      Rails.logger.info("Zipkin: Starting span")
      span = Span.new(name, trace_id)
      store_span(trace_id, span)
      span
    end

    def flush!
      raise "not implemented"
    end

    private

    THREAD_KEY = :zipkin_spans

    def spans
      Thread.current[THREAD_KEY] ||= []
    end

    def store_span(id, span)
      spans.push(span)
    end

    def reset
      Thread.current[THREAD_KEY] = []
    end

  end
end
