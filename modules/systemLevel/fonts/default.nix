{
  config,
  pkgs,
  ...
}: {
  # Fontconfig is on by default on NixOS, but leaving this here is harmless.
  fonts = {
    packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.hack
      # nerd-fonts.symbols-only   # handy for terminals/prompt glyphs
      # nerdfonts                 # HUGE meta-package with many fonts
    ];

    # Optional: influence defaults for apps that ask for “monospace/serif/sans”
    fontconfig = {
      defaultFonts.monospace = ["JetBrainsMono Nerd Font" "Hack Nerd Font"];
      # defaultFonts.sansSerif = [ "Inter" ];
      # defaultFonts.serif     = [ "Noto Serif" ];
    };
  };
}
