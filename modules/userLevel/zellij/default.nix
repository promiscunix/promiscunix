{...}: {
  programs.zellij.enable = true;

  xdg.configFile."zellij/config.kdl".text = ''
    // Zellij Configuration - Managed by Nix
    //
    // USER CUSTOMIZATION:
    // Zellij doesn't yet support config includes (PR #3899 pending).
    // For now, if you need customizations:
    // 1. Remove this module from your home.nix imports
    // 2. Copy this config to ~/.config/zellij/config.kdl
    // 3. Customize as needed
    //
    // Future: Once zellij supports includes, we'll add:
    // include "~/.config/zellij/user-overrides.kdl"

    plugins {
      tab-bar { path "tab-bar"; }
      status-bar { path "status-bar"; }  // <-- shows the keybinding hints
    }

    theme "catppuccin-mocha"
  '';

  # Template for future use (when zellij supports includes)
  xdg.configFile."zellij/user-overrides.kdl.template" = {
    text = ''
      // Zellij User Overrides
      //
      // This file will be included once zellij supports the include directive.
      // For now, this is a reference template.
      //
      // Example customizations:
      //
      // theme "gruvbox-dark"
      //
      // keybinds {
      //     normal {
      //         bind "Ctrl g" { SwitchToMode "locked"; }
      //     }
      // }
      //
      // See: https://zellij.dev/documentation/keybindings
    '';
    force = false;
  };
}
