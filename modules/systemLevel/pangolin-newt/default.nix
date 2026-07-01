# modules/systemLevel/pangolin-newt/default.nix
{
  pkgs,
  ...
}: {
  environment.systemPackages = [pkgs.fosrl-newt];

  systemd.services.newt = {
    description = "Newt connector for Pangolin";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    # Keep site credentials out of the git repo. Create this file locally with:
    # NEWT_ID=...
    # NEWT_SECRET=...
    # PANGOLIN_ENDPOINT=https://pangolin.part-suite.com
    unitConfig.ConditionPathExists = "/etc/newt/newt.env";

    serviceConfig = {
      Type = "simple";
      User = "root";
      Group = "root";
      EnvironmentFile = "/etc/newt/newt.env";
      ExecStart = "${pkgs.fosrl-newt}/bin/newt";
      Restart = "always";
      RestartSec = 2;
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };
}
