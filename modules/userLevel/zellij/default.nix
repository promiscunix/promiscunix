{...}: {
  programs.zellij.enable = true;

  # keep auto-backups so HM won’t fail if a file exists
  # home-manager.backupFileExtension = "backup";

  xdg.configFile."zellij/config.kdl".text = ''
    plugins {
      tab-bar { path "tab-bar"; }
      status-bar { path "status-bar"; }  // <-- shows the keybinding hints
    }

    theme "catppuccin-mocha"
  '';
}
# {pkgs, ...}: {
#   programs.zellij = {
#     enable = true;
#     # This writes ~/.config/zellij/config.kdl
#     settings = {
#       # Zellij uses KDL; this line becomes:  theme "catppuccin-mocha"
#       theme = "catppuccin-mocha";
#     };
#   };
# }

