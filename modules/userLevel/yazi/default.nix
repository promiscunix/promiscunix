{pkgs, ...}: {
  # Force Helix as Yazi's editor, regardless of shell env.
  xdg.configFile."yazi/yazi.toml".text = ''
    [opener]
    edit = [
      { run = "${pkgs.helix}/bin/hx %s", block = true, for = "unix" },
    ]
  '';
}
