# modules/systemLevel/obscura-research/default.nix
{
  pkgs,
  lib,
  ...
}: let
  obscura = pkgs.stdenv.mkDerivation rec {
    pname = "obscura";
    version = "0.1.8";

    src = pkgs.fetchurl {
      url = "https://github.com/h4ckf0r0day/obscura/releases/download/v${version}/obscura-x86_64-linux.tar.gz";
      hash = "sha256-5U0HBUBH1BgCR/A76gjRvXJO8YWYKTMaQz2pcvlzmIs=";
    };

    nativeBuildInputs = [pkgs.autoPatchelfHook];
    buildInputs = [
      pkgs.glibc
      pkgs.stdenv.cc.cc.lib
    ];

    unpackPhase = ''
      runHook preUnpack
      tar -xzf "$src"
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 obscura "$out/bin/obscura"
      install -Dm755 obscura-worker "$out/bin/obscura-worker"
      runHook postInstall
    '';

    meta = with lib; {
      description = "Headless browser for AI agents and web scraping";
      homepage = "https://github.com/h4ckf0r0day/obscura";
      license = licenses.asl20;
      platforms = ["x86_64-linux"];
      mainProgram = "obscura";
    };
  };

  obscuraResearchQueue = pkgs.writeShellApplication {
    name = "obscura-research-queue";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.python3
      obscura
    ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./scripts/obscura-research-queue.py} --obscura-bin ${obscura}/bin/obscura "$@"
    '';
  };
in {
  environment.systemPackages = [
    obscura
    obscuraResearchQueue
  ];
}
