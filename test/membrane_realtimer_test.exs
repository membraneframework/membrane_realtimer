defmodule Membrane.RealtimerTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.{Buffer, Testing, Time, Realtimer}

  test "Limits playback speed to realtime" do
    buffers = [
      %Buffer{pts: 0, payload: 0},
      %Buffer{pts: Time.milliseconds(100), payload: 1}
    ]

    {:ok, pipeline} =
      [
        src1: %Testing.Source{output: Testing.Source.output_from_buffers(buffers)},
        realtimer: Realtimer,
        sink: Testing.Sink
      ]
      |> Membrane.ParentSpec.link_linear()
      |> then(&Testing.Pipeline.start_link(links: &1))

    assert_sink_buffer(pipeline, :sink, %Buffer{payload: 0})
    refute_sink_buffer(pipeline, :sink, _buffer, 90)
    assert_sink_buffer(pipeline, :sink, %Buffer{payload: 1}, 20)
    assert_end_of_stream(pipeline, :sink)
    refute_sink_buffer(pipeline, :sink, _buffer, 0)
    Testing.Pipeline.terminate(pipeline, blocking?: true)
  end
end
