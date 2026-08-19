# Role: `desktop`

**Desktop fonts and the low-latency audio stack.**

## Role Variables

| Variable | Type | Required | Default | Description |
|---|---|---|---|---|
| `desktop_install_fonts` | `bool` | false | `true` | Install the font set. |
| `desktop_font_packages` | `list` | false | `None` | Font APT packages. |
| `desktop_install_audio` | `bool` | false | `true` | Install PipeWire and media tooling. |
| `desktop_audio_packages` | `list` | false | `None` | Audio and media APT packages. |
| `desktop_enable_realtime_audio` | `bool` | false | `true` | Deploy PAM limits and enable rtkit for real-time scheduling. |
| `desktop_realtime_groups` | `list` | false | `None` | POSIX groups granted real-time priority. |
| `desktop_realtime_rtprio` | `int` | false | `95` | Maximum real-time priority. Keep below 99. |
| `desktop_realtime_nice` | `int` | false | `-19` | Minimum nice value for the real-time groups. |
