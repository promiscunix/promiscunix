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
    description = "nixos-rebuild switch by host name over Tailscale";
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

      set -l target_name (string lower $host)
      set -l target_ip (${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -r --arg host "$target_name" '
        .Peer // {} | to_entries[] | .value
        | select(
            ((.HostName // "") | ascii_downcase) == $host
            or (((.DNSName // "") | split(".")[0]) | ascii_downcase) == $host
          )
        | .TailscaleIPs[0] // empty
      ' | ${pkgs.coreutils}/bin/head -n 1)
      if test -z "$target_ip"
        echo "nrs: no Tailscale peer found for $host"
        return 1
      end

      nixos-rebuild switch --flake "$root#$host" --target-host "$user@$target_ip" $sudo_flag
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
