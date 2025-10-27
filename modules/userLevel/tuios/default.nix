{pkgs, ...}: let
  tuios = pkgs.buildGoModule rec {
    pname = "tuios";
    version = "0.1.0"; # Update with actual version from repo

    src = pkgs.fetchFromGitHub {
      owner = "Gaurav-Gosain";
      repo = "tuios";
      rev = "main"; # or specific commit/tag
      sha256 = "sha256-09iqgxn48xpkgv8vx8wqam991vn89qv52ppfsxgmfzax11i3nykn=";
    };

    vendorHash = ""; # Will be filled by Nix

    meta = with pkgs.lib; {
      description = "Terminal UI OS - Terminal Multiplexer";
      homepage = "https://github.com/Gaurav-Gosain/tuios";
      license = licenses.mit;
      maintainers = [];
    };
  };
in {
  home.packages = [tuios];

  # Optional: Add any tuios-specific configuration
  # home.file.".config/tuios/config.toml".text = ''
  #   # tuios configuration here
  # '';
}
