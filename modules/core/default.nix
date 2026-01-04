# modules/core/default.nix
{ lib, systemInfo, ... }: let
  profile = systemInfo.profile or "workstation";
in {
  imports =
    [
      ../systemLevel/networking
      ../systemLevel/tailscale
      ../systemLevel/optimize/shared
      ../systemLevel/fonts
    ]
    ++ lib.optionals (profile != "server") [
      ../systemLevel/testing
    ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  boot.supportedFilesystems = ["btrfs"];

  nixpkgs.config.allowUnfree = true;

  security.sudo.wheelNeedsPassword = false;

  nix.settings.experimental-features = ["nix-command" "flakes"];

  documentation.man.generateCaches = false;

  time.timeZone = "America/Vancouver";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [22];

  programs.ssh.startAgent = true; # start a user ssh-agent
  programs.ssh.agentTimeout = "1h"; # optional
}
