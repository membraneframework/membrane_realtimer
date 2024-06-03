defmodule Membrane.Realtimer do
  @moduledoc """
  Sends buffers to the output in real time, according to buffers' timestamps.

  If buffers come in slower than realtime, they're sent as they come in.
  """
  use Membrane.Filter

  alias Membrane.Buffer

  def_input_pad :input, accepted_format: _any, flow_control: :manual, demand_unit: :buffers
  def_output_pad :output, accepted_format: _any, flow_control: :push

  def_options start_on_first_buffer?: [
                spec: boolean(),
                default: false,
                description: """
                  If true, the timer is started when the first buffer arrives.
                  Otherwise, the timer is started when the element goes into the `playing` playback.

                  Defaults to false.
                """
              ]

  @impl true
  def handle_init(_ctx, opts) do
    {[],
     %{
       previous_timestamp: nil,
       tick_actions: [],
       start_on_first_buffer?: opts.start_on_first_buffer?
     }}
  end

  @impl true
  def handle_playing(_ctx, state) do
    maybe_start_timer =
      if state.start_on_first_buffer?, do: [], else: [start_timer: {:timer, :no_interval}]

    {maybe_start_timer ++ [demand: {:input, 1}], state}
  end

  @impl true
  def handle_start_of_stream(:input, _ctx, state) do
    maybe_start_timer =
      if state.start_on_first_buffer?, do: [start_timer: {:timer, :no_interval}], else: []

    {maybe_start_timer, state}
  end

  @impl true
  def handle_buffer(:input, buffer, ctx, %{previous_timestamp: nil} = state) do
    handle_buffer(:input, buffer, ctx, %{
      state
      | previous_timestamp: Buffer.get_dts_or_pts(buffer) || 0
    })
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) do
    interval = Buffer.get_dts_or_pts(buffer) - state.previous_timestamp

    state = %{
      state
      | previous_timestamp: Buffer.get_dts_or_pts(buffer),
        tick_actions: [buffer: {:output, buffer}] ++ state.tick_actions
    }

    {[timer_interval: {:timer, interval}], state}
  end

  @impl true
  def handle_event(pad, event, _ctx, %{tick_actions: tick_actions} = state)
      when pad == :output or tick_actions == [] do
    {[forward: event], state}
  end

  @impl true
  def handle_event(:input, event, _ctx, state) do
    {[], %{state | tick_actions: [event: {:output, event}] ++ state.tick_actions}}
  end

  @impl true
  def handle_stream_format(:input, stream_format, _ctx, %{tick_actions: []} = state) do
    {[forward: stream_format], state}
  end

  @impl true
  def handle_stream_format(:input, stream_format, _ctx, state) do
    {[], %{state | tick_actions: [stream_format: {:output, stream_format}] ++ state.tick_actions}}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, %{tick_actions: []} = state) do
    {[end_of_stream: :output], state}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    {[], %{state | tick_actions: [end_of_stream: :output] ++ state.tick_actions}}
  end

  @impl true
  def handle_tick(:timer, _ctx, state) do
    actions =
      [timer_interval: {:timer, :no_interval}] ++
        Enum.reverse(state.tick_actions) ++ [demand: {:input, 1}]

    {actions, %{state | tick_actions: []}}
  end
end
