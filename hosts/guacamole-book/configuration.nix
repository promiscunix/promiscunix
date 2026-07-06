# hosts/guacamole-book/configuration.nix
# Lenovo ideapad 2in1 11 / 81CX repurposed as a low-RAM Guacamole thin client.
{
  lib,
  pkgs,
  userInfo,
  ...
}: let
  guacamoleUrl = "https://guacamole.part-suite.com";
  kioskSession = pkgs.writeShellApplication {
    name = "guacamole-book-session";
    runtimeInputs = with pkgs; [firefox-esr cage];
    text = ''
      export MOZ_ENABLE_WAYLAND=1
      export MOZ_USE_XINPUT2=1
      export GDK_BACKEND=wayland

      exec cage -s -- firefox-esr --kiosk ${lib.escapeShellArg guacamoleUrl}
    '';
  };
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
  ];

  # Keep this machine appliance-like: no Home Manager desktop stack, no full DE.
  users.users.damajha = {
    isNormalUser = true;
    description = userInfo.fullName or "Dale Appleby";
    extraGroups = ["wheel" "networkmanager" "video" "audio" "input"];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = userInfo.sshKeys or [];
  };

  programs.fish.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${kioskSession}/bin/guacamole-book-session";
        user = "damajha";
      };
    };
  };

  # Browser/kiosk essentials only.
  environment.systemPackages = with pkgs; [
    firefox-esr
    cage
    networkmanager
    networkmanagerapplet
    brightnessctl
    wl-clipboard
  ];

  # Low-RAM survival settings for the 2GB laptop.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = lib.mkForce 100;
  };

  nix.settings = {
    max-jobs = lib.mkDefault 1;
    cores = lib.mkDefault 1;
  };

  # Avoid wasting RAM/disk on docs for an appliance.
  documentation = {
    enable = lib.mkDefault false;
    man.enable = lib.mkDefault false;
    info.enable = lib.mkDefault false;
    nixos.enable = lib.mkDefault false;
  };

  # Small local console fallback if kiosk fails.
  services.openssh.enable = true;

  system.stateVersion = "25.05";
}
