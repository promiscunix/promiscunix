{
  config,
  lib,
  ...
}: {
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [8409];

  systemd.tmpfiles.rules = [
    "d /var/lib/ersatztv 0755 root root -"
  ];

  virtualisation.oci-containers.containers.ersatztv = {
    image = "ghcr.io/ersatztv/ersatztv:latest";
    ports = ["8409:8409"];
    volumes = [
      "/var/lib/ersatztv:/config"
      "/mnt/nas/media:/mnt/nas/media:ro"
    ];
    environment = {
      TZ = config.time.timeZone;
    };
    extraOptions = [
      "--tmpfs=/transcode"
      "--device=/dev/dri/renderD128"
    ];
  };
}
