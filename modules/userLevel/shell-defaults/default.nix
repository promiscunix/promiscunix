{
  lib,
  pkgs,
  userInfo,
  ...
}: let
  shellName = userInfo.shell or "fish";
  editorName = userInfo.editor or "helix";

  shellPath =
    if builtins.hasAttr shellName pkgs
    then "${pkgs.${shellName}}/bin/${shellName}"
    else shellName;

  editorCmd =
    if editorName == "helix"
    then "${pkgs.helix}/bin/hx"
    else if builtins.hasAttr editorName pkgs
    then "${pkgs.${editorName}}/bin/${editorName}"
    else editorName;
in {
  home.sessionVariables = {
    SHELL = shellPath;
    EDITOR = editorCmd;
    VISUAL = editorCmd;
  };

  # If someone drops into bash/zsh interactively, bounce them into fish.
  programs.bash = lib.mkIf (shellName == "fish") {
    enable = true;
    initExtra = ''
      if [ -t 1 ] && [ -z "$FISH_VERSION" ]; then
        exec ${pkgs.fish}/bin/fish
      fi
    '';
  };

  programs.zsh = lib.mkIf (shellName == "fish") {
    enable = true;
    initContent = ''
      if [[ -o interactive && -z "$FISH_VERSION" ]]; then
        exec ${pkgs.fish}/bin/fish
      fi
    '';
  };
}
