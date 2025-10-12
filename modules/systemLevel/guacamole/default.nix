{
  pkgs,
  config,
  lib,
  ...
}: {
  # services.xserver.enable = true;
  # services.xserver.desktopManager.xfce.enable = true;
  # services.xrdp.enable = true;
  # services.xrdp.defaultWindowManager = "startxfce4";
  # services.xrdp.audio.enable = false;
  # services.xrdp.openFirewall = true;

  # # guacd (RDP/VNC/SSH back-end)
  # services.guacamole-server = {
  #   enable = true;
  #   host = "127.0.0.1";
  #   port = 4822;
  #   # REMOVE this line (auth is not done by guacd):
  #   # userMappingXml = ./user-mapping.xml;
  # };

  # # Web app (Tomcat) front-end
  # services.guacamole-client = {
  #   enable = true;
  #   enableWebserver = true; # http://HOST:8080/guacamole/
  #   settings = {
  #     guacd-hostname = "127.0.0.1";
  #     guacd-port = 4822;
  #     # no need to set any 'user-mapping' property; the client reads /etc/guacamole by default
  #   };
  # };

  # 1) guacd proxy
  services.guacamole-server.enable = true;

  # 2) web-UI client
  services.guacamole-client.enable = true;
  services.guacamole-client.enableWebserver = true;
  services.guacamole-client.settings = {
    guacd-hostname = "127.0.0.1";
    guacd-port = 4822;
    basic-user-mapping = "/etc/guacamole/user-mapping.xml";
  };

  environment.etc."guacamole/user-mapping.xml".source = ./user-mapping.xml;
  # 3) open firewall
  networking.firewall.allowedTCPPorts = [4822 8080];
}
# Put the mapping where the web app actually looks:
# environment.etc."guacamole/user-mapping.xml".source = ./user-mapping.xml;
# networking.firewall = {
#   enable = true;
#   allowedTCPPorts = [8080 3389 4822];
# };
# environment.systemPackages = with pkgs; [i3 xterm freerdp];
# }

