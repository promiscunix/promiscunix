{...}: {
  # HM manages user-level fish config
  programs.fish.enable = true;

  programs.starship = {
    enable = true;
    enableFishIntegration = true;

    # writes ~/.config/starship.toml
    settings = {
      add_newline = true;

      # Line 1: time + directory (+ git if present) … fill to right … blue elbow
      # Line 2: matching elbow + your prompt character
      format = ''
        $username$hostname $time $directory( on $git_branch$git_status)$fill[╭─](bold blue)
        [╰─](bold blue)$character
      '';

      # prompt symbols (keep monospace-friendly)
      character = {
        success_symbol = "[❯](bold blue) ";
        error_symbol = "[❯](bold red) ";
        vicmd_symbol = "[❮](bold yellow) ";
      };

      # your request: username + hostname blocks
      username = {
        show_always = true;
        format = "[$user]($style)";
        style_user = "bold mauve";
        style_root = "bold red";
      };

      hostname = {
        ssh_only = false; # show even when not SSH
        ssh_symbol = ""; # no 🌐
        format = "[@$hostname]($style)";
        style = "bold sapphire";
      };

      # keep path tidy; stops at repo root
      directory = {
        truncate_to_repo = true;
        truncation_length = 2;
      };

      # git bits
      git_branch = {
        format = "[ $branch]($style)";
        style = "bold purple";
      };
      git_status = {
        format = "[$all_status$ahead_behind]($style)";
        style = "yellow";
      };

      # time (12-hour)
      time = {
        disabled = false;
        format = "[$time]($style) ";
        time_format = "%I:%M %p";
        use_12hr = true;
        utc_time_offset = "local";
        style = "bold dimmed mauve"; # uses palette color
      };

      # Catppuccin Mocha palette (once!)
      palette = "catppuccin_mocha";
      palettes.catppuccin_mocha = {
        rosewater = "#f5e0dc";
        flamingo = "#f2cdcd";
        pink = "#f5c2e7";
        mauve = "#cba6f7";
        red = "#f38ba8";
        maroon = "#eba0ac";
        peach = "#fab387";
        yellow = "#f9e2af";
        green = "#a6e3a1";
        teal = "#94e2d5";
        sky = "#89dceb";
        sapphire = "#74c7ec";
        blue = "#89b4fa";
        lavender = "#b4befe";
        text = "#cdd6f4";
        subtext1 = "#bac2de";
        subtext0 = "#a6adc8";
        overlay2 = "#9399b2";
        overlay1 = "#7f849c";
        overlay0 = "#6c7086";
        surface2 = "#585b70";
        surface1 = "#45475a";
        surface0 = "#313244";
        base = "#1e1e2e";
        mantle = "#181825";
        crust = "#11111b";
      };
    };
  };
}
