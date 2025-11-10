{
  pkgs,
  lib,
  ...
}: let
  tuios = pkgs.buildGoModule rec {
    pname = "tuios";
    version = "0.1.0"; # adjust when tagging upstream

    src = pkgs.fetchFromGitHub {
      owner = "Gaurav-Gosain";
      repo = "tuios";
      # Prefer a branch ref for now; can pin to a commit once stable
      rev = "main";
      hash = "sha256-DE232gQnPRwbAudkpcdg0HwUZZmLpQzr5bBT8nk60k8=";
    };

    # vendorHash = "sha256-DE232gQnPRwbAudkpcdg0HwUZZmLpQzr5bBT8nk60k8="; # leave empty to get expected hash from the next build
    vendorHash = "sha256-9FXltae1oNiciUY3EjS3+xwtmrB25TP4ajeo1MH1L7k="; # leave empty to get expected hash from the next build

    # If upstream has multiple cmd packages, set subPackages accordingly.
    # subPackages = [ "." ];

    meta = with lib; {
      description = "Terminal UI OS - Terminal Multiplexer";
      homepage = "https://github.com/Gaurav-Gosain/tuios";
      license = licenses.mit;
      maintainers = [];
    };
  };
in {
  home.packages = [tuios];
}
