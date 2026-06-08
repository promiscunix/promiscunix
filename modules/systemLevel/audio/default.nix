# modules/systemLevel/audio/default.nix
{ pkgs, ... }: {
  # Modern Linux audio stack: PipeWire replaces PulseAudio/JACK while
  # preserving PulseAudio compatibility for desktop apps.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  security.rtkit.enable = true;

  environment.systemPackages = with pkgs; [
    alsa-utils     # alsamixer, speaker-test
    pavucontrol    # GUI mixer / device chooser
    pamixer        # CLI PulseAudio/PipeWire volume control
    playerctl      # media playback controls
    pulseaudio     # pactl/pacmd compatibility tools
    wireplumber    # wpctl
  ];
}
