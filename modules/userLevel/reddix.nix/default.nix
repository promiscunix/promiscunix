{ lib, pkgs, config, ... }:
let
  cfg = config.programs.reddix;

  # --- Option A: prebuilt binaries from GitHub releases (simple; no cargoHash) ---
  # Fill the two hashes after first build (instructions below).
  version = "0.1.14";
  platform = pkgs.stdenv.hostPlatform.system; # "x86_64-linux" | "aarch64-linux" | etc.
  assetMap = {
    "x86_64-linux" = {
      url = "https://github.com/ck-zhang/reddix/releases/download/v${version}/reddix-x86_64-unknown-linux-gnu.tar.xz";
      hash = "<fill-me-linux-x86_64>";
    };
    "aarch64-linux" = {
      url = "https://github.com/ck-zhang/reddix/releases/download/v${version}/reddix-aarch64-unknown-linux-gnu.tar.xz";
      hash = "<fill-me-linux-aarch64>";
    };
  };
  haveAsset = builtins.hasAttr platform assetMap;
  srcPrebuilt =
    if haveAsset then
      pkgs.fetchzip {
        url = assetMap.${platform}.url;
        hash = assetMap.${platform}.hash; # fill after first build
        stripRoot = false;
      }
    else
      null;

  reddixPrebuilt =
    if haveAsset then
      pkgs.stdenvNoCC.mkDerivation {
        pname = "reddix";
        inherit version;
        src = srcPrebuilt;
        installPhase = ''
          mkdir -p $out/bin
          # archive contains a single "reddix" binary
          install -m755 reddix $out/bin/reddix
        '';
      }
    else
      null;

  # --- Option B: build from source (portable; needs cargoHash) ---
  # Uncomment to use source build and comment the prebuilt default below.
  # reddixFromSource = pkgs.rustPlatform.buildRustPackage {
  #   pname = "reddix";
  #   inherit version;
  #   src = pkgs.fetchFromGitHub {
  #     owner = "ck-zhang";
  #     repo  = "reddix";
  #     rev   = "v${version}";
  #     hash  = "<fill-me-src-sha256>";
  #   };
  #   cargoHash = "<fill-me-cargoHash>";
  #   # Add native deps if the project needs them; none known from upstream README.
  #   nativeBuildInputs = [ ];
  #   buildInputs = [ ];
  # };

in
{
  options.programs.reddix = {
    enable = lib.mkEnableOption "Reddix - Reddit TUI client";

    package = lib.mkOption {
      type = lib.types.package;
      default =
        if haveAsset && reddixPrebuilt != null then reddixPrebuilt
        else (throw "programs.reddix: unsupported platform ${platform}; use source build block.");
      description = "Package to install for Reddix (prebuilt by default).";
    };

    config = {
      clientId = lib.mkOption {
        type = lib.types.str;
        example = "abcd1234";
        description = "Reddit app client_id";
      };
      clientSecret = lib.mkOption {
        type = lib.types.str;
        example = "supersecret";
        description = "Reddit app client_secret";
      };
      redirectUri = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:65010/reddix/callback";
        description = "OAuth redirect URI (matches Reddit app setting).";
      };
      extraSettings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
        description = "Additional config.yaml keys to merge in.";
      };
      manageConfig = lib.mkOption {
        type = lib.types.bool;
        default = false; # default false to avoid putting secrets in the Nix store
        description = "If true, Home Manager will write ~/.config/reddix/config.yaml";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Only write config if explicitly opted-in (secrets risk).
    xdg.configFile."reddix/config.yaml" = lib.mkIf cfg.config.manageConfig {
      # WARNING: Puts secrets into the Nix store; prefer sops-nix/agenix (see notes).
      text = lib.generators.toYAML {} ({
        client_id     = cfg.config.clientId;
        client_secret = cfg.config.clientSecret;
        redirect_uri  = cfg.config.redirectUri;
      } // cfg.config.extraSettings);
    };
  };
}
