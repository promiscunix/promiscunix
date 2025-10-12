# modules/systemLevel/optimizations/shared.nix
{
  lib,
  pkgs,
  ...
}: {
  #### Tools (common)
  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
    lshw
    hwinfo
    fastfetch
    smartmontools
    nvme-cli
    lm_sensors
    ethtool
    dmidecode
  ];
  #### Firmware & sensors
  services.fwupd.enable = true;
  #### CPU microcode, thermals, IRQ balance
  hardware.cpu.intel.updateMicrocode = true;
  services.thermald.enable = true;
  services.irqbalance.enable = true;
  #### zram swap (host can override memoryPercent)
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = lib.mkDefault 25; # override to 50 on OptiPlex, etc.
  };
  #### Nix store hygiene
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    optimise.automatic = true;
    settings = {
      experimental-features = ["nix-command" "flakes"];
      http-connections = lib.mkDefault 50;
      auto-optimise-store = true;
    };
  };
  #### SSD TRIM
  services.fstrim.enable = true;
  #### SMART monitoring (enabled here; device list per host)
  services.smartd.enable = true;
}
