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

  programs.fish.functions.nrs = {
    description = "nixos-rebuild switch by host name (tailscaleIp from systemInfo.toml)";
    body = ''
      argparse 'u/user=' 's/sudo' -- $argv; or return 2
      if test (count $argv) -lt 1
        echo "usage: nrs HOST [--user USER] [--sudo]"
        return 2
      end

      set -l host $argv[1]
      set -l user (set -q _flag_user; and echo $_flag_user; or echo root)
      set -l sudo_flag (set -q _flag_sudo; and echo --sudo)

      set -l root ""
      if set -q PROMISCUNIX_ROOT
        set root $PROMISCUNIX_ROOT
      else
        set root (git -C (pwd) rev-parse --show-toplevel 2>/dev/null)
      end

      if test -z "$root"
        echo "nrs: set PROMISCUNIX_ROOT or run inside the repo"
        return 1
      end

      set -l sysfile "$root/hosts/$host/systemInfo.toml"
      if not test -f $sysfile
        echo "nrs: missing $sysfile"
        return 1
      end

      set -l expr "let s = builtins.fromTOML (builtins.readFile \\\"$sysfile\\\"); in s.tailscaleIp or \\\"\\\""
      set -l ip (nix eval --raw --expr "$expr")
      if test -z "$ip"
        echo "nrs: tailscaleIp not set in $sysfile"
        return 1
      end

      nixos-rebuild switch --flake "$root#$host" --target-host "$user@$ip" $sudo_flag
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
