# modules/systemLevel/web-terminal/default.nix
{
  pkgs,
  systemInfo,
  ...
}: let
  user = systemInfo.mainUser;
in {
  environment.systemPackages = [pkgs.ttyd];

  systemd.services.web-terminal = {
    description = "Local ttyd browser terminal for Pangolin";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      User = user;
      Group = "users";
      # libwebsockets 4.4.x loads its evlib_uv plugin from the process cwd
      # before the compiled install libdir on this NixOS build.  Keep ttyd's
      # process cwd on the libwebsockets plugin directory, while --cwd below
      # still opens the user's shell in /home/${user}.
      WorkingDirectory = "${pkgs.libwebsockets}/lib";
      ExecStart = "${pkgs.ttyd}/bin/ttyd --interface 127.0.0.1 --port 7681 --writable --max-clients 2 --cwd /home/${user} ${pkgs.fish}/bin/fish -l";
      Restart = "always";
      RestartSec = 2;
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };
}
