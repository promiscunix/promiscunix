{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: {
  imports = [
    ../sops # Base SOPS configuration
  ];

  # SOPS secrets for Guacamole credentials
  sops = {
    defaultSopsFile = ./secrets/user-mapping.yaml;

    secrets = {
      guacamole_username = {};
      guacamole_password = {};
      rdp_username = {};
      rdp_password = {};
    };
  };

  # 1) guacd proxy (the native RDP/VNC/SSH protocol handler)
  services.guacamole-server = {
    enable = true;
    host = "127.0.0.1"; # Only listen locally
    port = 4822;
  };

  # 2) web-UI client (Tomcat-based web interface)
  services.guacamole-client = {
    enable = true;
    enableWebserver = true;
    settings = {
      guacd-hostname = "127.0.0.1";
      guacd-port = 4822;
    };
  };

  # Change Tomcat port to avoid conflict with SABnzbd (8080)
  services.tomcat.port = 8081;

  # Generate user-mapping.xml from SOPS secrets at activation
  system.activationScripts.guacamole-user-mapping = {
    deps = [ "setupSecrets" ]; # Run after sops decrypts secrets
    text = let
      guacUser = config.sops.secrets.guacamole_username.path;
      guacPass = config.sops.secrets.guacamole_password.path;
      rdpUser = config.sops.secrets.rdp_username.path;
      rdpPass = config.sops.secrets.rdp_password.path;
    in ''
    GUAC_USER=$(cat ${guacUser})
    GUAC_PASS=$(cat ${guacPass})
    RDP_USER=$(cat ${rdpUser})
    RDP_PASS=$(cat ${rdpPass})

    cat > /etc/guacamole/user-mapping.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<user-mapping>
XMLEOF
    cat >> /etc/guacamole/user-mapping.xml << EOF
  <authorize username="$GUAC_USER" password="$GUAC_PASS">
    <connection name="Plasma Desktop">
      <protocol>rdp</protocol>
      <param name="hostname">127.0.0.1</param>
      <param name="port">3389</param>
      <param name="username">$RDP_USER</param>
      <param name="password">$RDP_PASS</param>
      <param name="security">any</param>
      <param name="ignore-cert">true</param>
      <param name="color-depth">24</param>
      <param name="enable-wallpaper">true</param>
      <param name="enable-theming">true</param>
      <param name="enable-font-smoothing">true</param>
      <param name="enable-desktop-composition">true</param>
      <param name="resize-method">display-update</param>
      <param name="enable-audio">true</param>
    </connection>
  </authorize>
</user-mapping>
EOF

    chown root:tomcat /etc/guacamole/user-mapping.xml
    chmod 440 /etc/guacamole/user-mapping.xml
  '';
  };

  # Firewall: only expose web UI port, keep guacd internal
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [8081];
}
