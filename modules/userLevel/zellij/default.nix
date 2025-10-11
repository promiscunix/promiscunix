{...}: {
  programs.zellij.enable = true;

  xdg.configFile."zellij/config.kdl".text = ''
    plugins {
      tab-bar { path "tab-bar"; }
      status-bar { path "status-bar"; }  // <-- shows the keybinding hints
    }

    theme "catppuccin-mocha"
  '';
}
