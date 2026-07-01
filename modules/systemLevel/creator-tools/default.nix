# modules/systemLevel/creator-tools/default.nix
{ pkgs, ... }: {
  # Video/audio creator workstation tools for screen recording, streaming,
  # camera setup, audio routing, editing, and quick media conversion.
  environment.systemPackages = with pkgs; [
    obs-studio     # screen recording / streaming / scene composition
    kdePackages.kdenlive # non-linear video editor
    audacity       # voice/audio recording and cleanup
    qpwgraph       # PipeWire graph/patchbay for routing apps, mics, and monitors
    easyeffects    # PipeWire audio effects/noise cleanup chain
    v4l-utils      # webcam/device inspection and controls
    guvcview       # simple webcam preview and camera control UI
    ffmpeg         # capture/transcode swiss-army knife
  ];
}
