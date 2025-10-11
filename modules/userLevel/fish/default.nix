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
    '';
  };
}
