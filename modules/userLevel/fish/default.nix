{
  pkgs,
  config,
  ...
}: {
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      function fish_right_prompt
        starship module time
      end

      # Source user overrides if present
      if test -f ~/.config/fish/user-overrides.fish
          source ~/.config/fish/user-overrides.fish
      end
    '';
  };

  # Template for user overrides (won't overwrite if exists)
  xdg.configFile."fish/user-overrides.fish.template" = {
    text = ''
      # Fish User Overrides
      # Copy this file to ~/.config/fish/user-overrides.fish
      # This file is NOT managed by Nix - customize freely!
      #
      # Examples:
      # set -gx EDITOR helix
      # alias ll "ls -la --color=auto"
      # alias gs "git status"
      # set fish_greeting ""  # Disable greeting
    '';
    force = false;
  };
}
