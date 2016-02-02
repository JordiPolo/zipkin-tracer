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
      @traces_buffer = options[:traces_buffer] || raise(ArgumentError, 'A proper buffer must be setup for the Zipkin tracer')
      @logger = @options[:logger]
      reset
    end

    def with_new_span(trace_id, name)
      span = start_span(trace_id, name)
      result = yield span
      may_flush(span)
      result
    end

    def may_flush(span)
      @logger.info("MAY flush!")
      size = spans.values.map(&:size).inject(:+) || 0
      @logger.info("Size #{size}")
      if size >= @traces_buffer || span.annotations.any?{ |ann| ann == Annotation::SERVER_SEND }
        @logger.info("Flushing")
        flush!
        reset
      end
    end

    def start_span(trace_id, name)
      span = get_span_for_id(trace_id)
      span.name = name
      span
    end

    def flush!
      raise "not implemented"
    end

    private

    def spans
      Thread.current[:zipkin_spans] ||= {}
    end

    def get_span_for_id(id)
      key = id.span_id.to_s
      spans[key] ||= Span.new("", id)
    end

    def reset
      @logger.info("Reset")
      Thread.current[:zipkin_spans] = {}
    end
  end
end
