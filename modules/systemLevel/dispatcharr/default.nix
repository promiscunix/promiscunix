{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # open the web UI
  networking.firewall.allowedTCPPorts = [9191];

  systemd.tmpfiles.rules = [
    "d /var/lib/dispatcharr 0755 root root -"
  ];

  virtualisation.oci-containers.containers.dispatcharr = {
    image = "ghcr.io/dispatcharr/dispatcharr:latest";
    ports = ["9191:9191"];
    volumes = ["/var/lib/dispatcharr:/data"];
    environment = {
      DISPATCHARR_ENV = "aio";
      DISPATCHARR_LOG_LEVEL = "info";
      # These appear in Dispatcharr’s official compose example (safe to include)
      REDIS_HOST = "localhost";
      CELERY_BROKER_URL = "redis://localhost:6379/0";
    };
  };
}
