# modules/userLevel/helix/default.nix
{pkgs, ...}: {
  programs.helix = {
    enable = true;
    package = pkgs.helix;
    settings.theme = "catppuccin_mocha"; # use Helix's built-in
    languages = {
      "language-server".nil = {command = "${pkgs.nil}/bin/nil";};
      language = [
        {
          name = "nix";
          auto-format = true;
          "language-servers" = ["nil"];
          formatter = {
            command = "${pkgs.alejandra}/bin/alejandra";
            args = ["-qq"];
          };
        }
      ];
    };
  };
  home.packages = [pkgs.nil pkgs.alejandra];

  # Documentation for user overrides
  # Helix merges configs: ~/.helix/config.toml overrides ~/.config/helix/config.toml
  xdg.configFile."helix/README-overrides.md" = {
    text = ''
      # Helix User Customization

      Helix merges configuration from multiple sources (in order):
      1. Built-in defaults
      2. ~/.config/helix/config.toml (Nix-managed - DO NOT EDIT)
      3. ~/.helix/config.toml (YOUR overrides - create this!)
      4. .helix/config.toml (per-project overrides)

      ## To customize globally:

      Create ~/.helix/config.toml with your preferences:

      ```toml
      theme = "gruvbox"

      [editor]
      line-number = "relative"
      mouse = false
      bufferline = "multiple"

      [editor.cursor-shape]
      insert = "bar"
      normal = "block"
      select = "underline"

      [keys.normal]
      C-s = ":write"
      ```

      Settings in ~/.helix/ will override the Nix-managed config.
    '';
    force = false;
  };
}
