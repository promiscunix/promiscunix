# modules/core/default.nix
{ lib, systemInfo, pkgs, ... }: let
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
      ../systemLevel/audio
      ../systemLevel/testing
    ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  boot.supportedFilesystems = ["btrfs"];

  nixpkgs.config.allowUnfree = true;

  # Disable hanging apprise tests (WKD network lookups hang in sandbox)
  # Override the python3 used by sabnzbd directly for reliability.
  nixpkgs.overlays = [
    (final: prev: {
      sabnzbd = prev.sabnzbd.override {
        python3 = prev.python3.override {
          packageOverrides = self: super: {
            apprise = super.apprise.overridePythonAttrs (old: {
              doCheck = false;
            });
          };
        };
      };
    })
  ];

  security.sudo.wheelNeedsPassword = false;

  nix.settings.experimental-features = ["nix-command" "flakes"];

  documentation.man.cache.enable = false;

  time.timeZone = "America/Vancouver";

  environment.systemPackages = with pkgs; [
    git
  ];

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
