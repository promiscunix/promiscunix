# modules/userLevel/fresh/default.nix
# Fresh terminal editor, installed from upstream's static musl binary release.
# The upstream flake builds from source and currently pulls a very large Rust/WGPU
# build graph, so this module uses the prebuilt terminal binary instead.
{
  pkgs,
  ...
}: let
  version = "0.4.2";
  fresh = pkgs.stdenvNoCC.mkDerivation {
    pname = "fresh-editor-bin";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/sinelaw/fresh/releases/download/v${version}/fresh-editor-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-YUoROz2aitE0pEk6dzjeLzDDoeuDU9oVOyBGFlxkT6o=";
    };

    sourceRoot = "fresh-editor-x86_64-unknown-linux-musl";

    installPhase = ''
      runHook preInstall

      install -Dm755 fresh $out/bin/fresh
      install -Dm644 fresh.desktop $out/share/applications/fresh.desktop
      install -Dm644 LICENSE $out/share/licenses/fresh-editor/LICENSE
      cp -r icons $out/share/icons

      runHook postInstall
    '';

    meta = {
      description = "Modern terminal text editor with familiar keybindings, mouse support, and LSP features";
      homepage = "https://github.com/sinelaw/fresh";
      license = pkgs.lib.licenses.gpl2Only;
      mainProgram = "fresh";
      platforms = ["x86_64-linux"];
    };
  };
in {
  home.packages = [fresh];
}
