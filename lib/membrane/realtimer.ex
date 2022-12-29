defmodule Membrane.Realtimer do
  @moduledoc """
  Sends buffers to the output in real time, according to buffers' timestamps.

  If buffers come in slower than realtime, they're sent as they come in.
  """
  use Membrane.Filter

  alias Membrane.Buffer

  def_input_pad :input, accepted_format: _any, demand_unit: :buffers
  def_output_pad :output, accepted_format: _any, mode: :push

  @impl true
  def handle_init(_ctx, _opts) do
    {[], %{previous_timestamp: 0, tick_actions: []}}
  end

  @impl true
  def handle_playing(_ctx, state) do
    {[start_timer: {:timer, :no_interval}, demand: {:input, 1}], state}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    use Ratio
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
    {[], %{state | tick_actions: [caps: {:output, stream_format}] ++ state.tick_actions}}
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

  @impl true
  def handle_terminate_request(_ctx, state) do
    {[stop_timer: :timer], %{state | previous_timestamp: 0}}
  end
end
