{ pkgs, lib, ... }:
let
  tuios = pkgs.buildGoModule rec {
    pname = "tuios";
    version = "0.1.0"; # adjust when tagging upstream

    src = pkgs.fetchFromGitHub {
      owner = "Gaurav-Gosain";
      repo = "tuios";
      # Prefer a branch ref for now; can pin to a commit once stable
      rev = "main";
      hash = "sha256-cN8jubDeK+w8E6Mii6kyi2b/ugmqqfDk+sz1U4akBJc=";
    };

    vendorHash = "sha256-0hxj6EUTCV7R59XJheHj9PR/oWQH+2uzYOPhVQWa0hU="; # leave empty to get expected hash from the next build

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
  home.packages = [ tuios ];
}


