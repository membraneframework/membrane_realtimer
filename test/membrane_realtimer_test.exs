defmodule Membrane.FunnelTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.{Buffer, Testing, Time, Realtimer}

  test "Collects multiple inputs" do
    buffers = [
      %Buffer{payload: 0, metadata: %{timestamp: 0}},
      %Buffer{payload: 1, metadata: %{timestamp: Time.milliseconds(100)}}
    ]

    {:ok, pipeline} =
      %Testing.Pipeline.Options{
        elements: [
          src1: %Testing.Source{output: Testing.Source.output_from_buffers(buffers)},
          realtimer: Realtimer,
          sink: Testing.Sink
        ]
      }
      |> Testing.Pipeline.start_link()

    :ok = Testing.Pipeline.play(pipeline)

    assert_sink_buffer(pipeline, :sink, %Buffer{payload: 0})
    refute_sink_buffer(pipeline, :sink, _buffer, 90)
    assert_sink_buffer(pipeline, :sink, %Buffer{payload: 1}, 20)
    assert_end_of_stream(pipeline, :sink)
    refute_sink_buffer(pipeline, :sink, _buffer, 0)
  end
end
