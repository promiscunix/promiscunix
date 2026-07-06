# hosts/guacamole-book/hardware-configuration.nix
# Placeholder for the Lenovo ideapad 2in1 11 / 81CX thin-client install.
# Replace this file with the output of `sudo nixos-generate-config --show-hardware-config`
# after booting the real laptop installer.
{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "sdhci_pci"
    "rtsx_pci_sdmmc"
    "usb_storage"
    "usbhid"
  ];

  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  # Installer-friendly defaults. Adjust these to the real disk labels/UUIDs
  # generated on the laptop before switching this host for real use.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  swapDevices = [
    { device = "/swapfile"; size = 4096; }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
