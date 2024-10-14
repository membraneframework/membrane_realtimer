defmodule Membrane.Realtimer do
  @moduledoc """
  Sends buffers to the output in real time, according to buffers' timestamps.

  If buffers come in slower than realtime, they're sent as they come in.
  """
  use Membrane.Filter

  defmodule ResetEvent do
    @derive Membrane.EventProtocol
    defstruct []
  end

  alias Membrane.Buffer

  def_input_pad :input, accepted_format: _any, flow_control: :manual, demand_unit: :buffers
  def_output_pad :output, accepted_format: _any, flow_control: :push

  @impl true
  def handle_init(_ctx, _opts) do
    {[], %{previous_timestamp: nil, tick_actions: [], timer_status: :to_be_started}}
  end

  @impl true
  def handle_playing(_ctx, state) do
    {[demand: {:input, 1}], state}
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) do
    {maybe_start_timer, state} =
      if state.timer_status == :to_be_started,
        do: {[start_timer: {:timer, :no_interval}], %{state | timer_status: :running}},
        else: {[], state}

    state =
      with %{previous_timestamp: nil} <- state do
        %{state | previous_timestamp: Buffer.get_dts_or_pts(buffer) || 0}
      end

    interval = Buffer.get_dts_or_pts(buffer) - state.previous_timestamp

    state = %{
      state
      | previous_timestamp: Buffer.get_dts_or_pts(buffer),
        tick_actions: [buffer: {:output, buffer}] ++ state.tick_actions
    }

    {maybe_start_timer ++ [timer_interval: {:timer, interval}], state}
  end

  @impl true
  def handle_event(:input, %ResetEvent{}, _ctx, state) do
    {actions, state} =
      cond do
        state.tick_actions == [] and state.timer_status == :to_be_started ->
          {[], state}

        state.tick_actions == [] and state.timer_status == :running ->
          {[stop_timer: :timer], %{state | timer_status: :to_be_started}}

        state.tick_actions != [] ->
          {[], %{state | timer_status: :to_be_restarted}}
      end

    {actions, %{state | previous_timestamp: nil}}
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

    {maybe_stop_timer, state} =
      case state.timer_status do
        :to_be_restarted -> {[stop_timer: :timer], %{state | timer_status: :to_be_started}}
        :running -> {[], state}
      end

    {actions ++ maybe_stop_timer, %{state | tick_actions: []}}
  end
end
