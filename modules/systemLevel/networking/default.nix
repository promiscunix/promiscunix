{ config, pkgs, systemInfo, ... }:

{
    networking = {
    hostName = "mtac";
    networkmanager = {
      enable = true;  
      ensureProfiles.profiles = {
        "Wired Connection 1" = {
          connection.type = "ethernet";
          connection.id = "Wired Connection 1";
          connection.interface-name = "enp3s0";  # Make sure this matches your interface
          connection.autoconnect = true;
      
          ipv4.method = "manual";
          ipv4.addresses = "192.168.1.201/24";  #Desired IP address
          ipv4.gateway = "192.168.1.254";  #Routers IP address
          ipv4.dns = "8.8.8.8";
        };
      };
    };
  };
}
