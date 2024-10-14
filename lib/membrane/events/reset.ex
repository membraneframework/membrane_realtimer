
defmodule Membrane.Realtimer.Events.Reset do
  @moduledoc """
  Event, that resets `Membrane.Realtimer`.

  After receiving this event, `Membrane.Realtimer` will behave as if it would be freshly spawned.
  """

  @derive Membrane.EventProtocol
  defstruct []
end
