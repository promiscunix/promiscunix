{
  services.jellyfin = {
    enable = true;
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [8096];
}
