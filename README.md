# Membrane Realtimer plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_realtimer_plugin.svg)](https://hex.pm/packages/membrane_realtimer_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_realtimer_plugin/)
[![CircleCI](https://circleci.com/gh/membraneframework/membrane_realtimer_plugin.svg?style=svg)](https://circleci.com/gh/membraneframework/membrane_realtimer_plugin)

Membrane plugin for limiting playback speed to realtime, according to buffers' timestamps.

It is part of [Membrane Multimedia Framework](https://membraneframework.org).

## Installation

The package can be installed by adding `membrane_realtimer_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_realtimer_plugin, "~> 0.4.0"}
  ]
end
```

## Usage

The following pipeline downloads a sample h264 video via HTTP and sends it in realtime via RTP.
It requires [RTP plugin](https://github.com/membraneframework/membrane_rtp_plugin), [RTP H264 plugin](https://github.com/membraneframework/membrane_rtp_h264_plugin) and [UDP plugin](https://github.com/membraneframework/membrane_element_udp) to work.

```elixir
defmodule Example.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_opts) do
    ssrc = 1234

    spec = %ParentSpec{
      children: [
        source: %Membrane.Hackney.Source{
          location: "https://membraneframework.github.io/static/samples/ffmpeg-testsrc.h264"
        },
        parser: %Membrane.H264.FFmpeg.Parser{framerate: {30, 1}, alignment: :nal},
        rtp: Membrane.RTP.SessionBin,
        realtimer: Membrane.Realtimer,
        sink: %Membrane.Element.UDP.Sink{
          destination_port_no: 5000,
          destination_address: {127, 0, 0, 1}
        }
      ],
      links: [
        link(:src)
        |> to(:parser)
        |> via_in(Pad.ref(:input, ssrc))
        |> to(:rtp)
        |> via_out(Pad.ref(:rtp_output, ssrc), options: [encoding: :H264])
        |> to(:realtimer)
        |> to(:sink)
      ]
    }

    {{:ok, spec: spec}, %{}}
  end
end
```

## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_realtimer_plugin)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_realtimer_plugin)

Licensed under the [Apache License, Version 2.0](LICENSE)
