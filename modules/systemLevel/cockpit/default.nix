# modules/systemLevel/cockpit/default.nix
{
  pkgs,
  ...
}: {
  services.cockpit = {
    enable = true;
    port = 9090;
    openFirewall = false;
    showBanner = false;

    # Cockpit enforces same-origin checks for WebSocket traffic. Add the
    # public Pangolin resource origin so browser sessions work through the
    # reverse proxy/tunnel instead of only at https://localhost:9090.
    allowed-origins = [
      "https://cockpit.part-suite.com"
      "wss://cockpit.part-suite.com"
    ];

    settings.WebService = {
      # Cockpit sits behind Pangolin/Traefik TLS from the browser's perspective.
      ProtocolHeader = "X-Forwarded-Proto";
      ForwardedForHeader = "X-Forwarded-For";

      # Keep this host-local. Do not expose Cockpit as an SSH jump UI to other
      # hosts through the login screen.
      LoginTo = false;
    };
  };

  environment.systemPackages = [pkgs.cockpit];
}
