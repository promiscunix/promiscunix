{
  pkgs,
  config,
  lib,
  ...
}: {
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
