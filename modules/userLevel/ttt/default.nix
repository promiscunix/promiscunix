# modules/userLevel/ttt/default.nix
{
  pkgs,
  lib,
  ...
}: let
  ttt = pkgs.buildGo125Module rec {
    pname = "ttt";
    version = "0.3.1";

    src = pkgs.fetchFromGitHub {
      owner = "eugenioenko";
      repo = "ttt";
      rev = "v${version}";
      hash = "sha256-FFhYZMvniJQDVH4sHC/rBlK8pghYMbkiwHmKkIN7BLA=";
    };

    vendorHash = "sha256-WWVsY9ER0c6dN5AdMMynL3bti6nPkyJ80fCsuOwne9c=";

    subPackages = ["cmd/ttt"];
    ldflags = [
      "-s"
      "-w"
      "-X"
      "main.version=${version}"
    ];

    meta = {
      description = "Terminal Text Tool: terminal text editor IDE";
      homepage = "https://github.com/eugenioenko/ttt";
      license = lib.licenses.mit;
      mainProgram = "ttt";
      platforms = lib.platforms.unix;
    };
  };
in {
  home.packages = with pkgs; [
    ttt
    git
    ripgrep
  ];

  xdg.configFile."ttt/README-nixfiles.md" = {
    text = ''
      # TTT Editor

      This Home Manager module installs TTT Editor from GitHub:
      https://github.com/eugenioenko/ttt

      Included packages:
      - ttt: Terminal Text Tool editor
      - git: used by TTT's source-control features
      - ripgrep: used by TTT's workspace search

      Usage examples:
      ```sh
      ttt
      ttt .
      ttt /path/to/project
      ttt --workspace project.ttt
      ```

      TTT is intentionally zero-config. Put any future user-managed TTT config
      under ~/.config/ttt/ as normal files; do not edit this README in-place.
    '';
    force = false;
  };
}
