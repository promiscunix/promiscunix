# modules/systemLevel/optimize/optiplex/default.nix
# Intel Quick Sync hardware transcoding for Optiplex 3090 (UHD 630)
{
  pkgs,
  ...
}: {
  # Intel VA-API driver for hardware video acceleration
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD (for newer Intel GPUs)
      intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (fallback)
      libvdpau-va-gl # VDPAU backend for VA-API
      intel-compute-runtime # OpenCL support for Intel GPUs
    ];
  };

  # Add jellyfin user to video/render groups for hardware access
  users.users.jellyfin.extraGroups = ["video" "render"];

  # Environment variable to use the newer iHD driver
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  # Useful tools for verifying hardware acceleration
  environment.systemPackages = with pkgs; [
    libva-utils # vainfo command
    intel-gpu-tools # intel_gpu_top
  ];
}
