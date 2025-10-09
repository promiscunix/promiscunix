# modules/userLevel/helix/default.nix
{ pkgs, ... }: {
  programs.helix = {
    enable = true;
    package = pkgs.helix;
    settings.theme = "catppuccin_mocha";  # use Helix’s built-in
    languages = {
      "language-server".nil = { command = "${pkgs.nil}/bin/nil"; };
      language = [{
        name = "nix";
        auto-format = true;
        "language-servers" = [ "nil" ];
        formatter = {
          command = "${pkgs.alejandra}/bin/alejandra";
          args = [ "-qq" ];
        };
      }];
    };
  };
  home.packages = [ pkgs.nil pkgs.alejandra ];
}
