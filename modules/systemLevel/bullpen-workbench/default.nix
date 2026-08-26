# modules/systemLevel/bullpen-workbench/default.nix
{
  config,
  inputs,
  lib,
  pkgs,
  systemInfo,
  ...
}: let
  workbenchPort = 8788;
  selkiesPort = 8091;
  display = ":99";
  sharedDir = "/var/lib/bullpen-workbench/shared";
  dataDir = "/var/lib/bullpen-workbench/data";
  package = inputs.bullpen-workbench.packages.${pkgs.stdenv.hostPlatform.system}.bullpen-workbench;

  selkiesPortable = pkgs.stdenvNoCC.mkDerivation {
    pname = "selkies-gstreamer-portable";
    version = "1.6.2";
    src = pkgs.fetchurl {
      url = "https://github.com/selkies-project/selkies/releases/download/v1.6.2/selkies-gstreamer-portable-v1.6.2_amd64.tar.gz";
      hash = "sha256-Stu5WJYE5FOvwA5M6z8E4YhxH8tB11MW0LqMm6oHDO4=";
    };
    nativeBuildInputs = [pkgs.makeWrapper pkgs.patchelf];
    sourceRoot = ".";
    installPhase = ''
      runHook preInstall
      mkdir -p $out/opt $out/bin
      cp -R selkies-gstreamer $out/opt/selkies-gstreamer
      chmod -R u+w $out/opt/selkies-gstreamer

      # The upstream portable bundle is built for generic Linux and ships ELF
      # executables with /lib64/ld-linux-x86-64.so.2 as the interpreter. On
      # NixOS that trips stub-ld and exits 127 once the runner reaches bundled
      # Python. Patch executable ELF files to the Nix dynamic linker; the
      # runner still sets LD_LIBRARY_PATH to the bundled Conda lib directory.
      while IFS= read -r f; do
        if ${pkgs.file}/bin/file "$f" | grep -q 'ELF .*interpreter'; then
          patchelf --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} "$f" || true
        fi
      done < <(find $out/opt/selkies-gstreamer -type f -perm -0100)

      patchShebangs $out/opt/selkies-gstreamer/bin

      # Remote desktop first: the upstream web client waits for both the video
      # peer (1) and audio peer (3) before marking the session connected. In
      # this Xvfb/Openbox workbench, audio can stall the UI at "Registering
      # with server, peer ID: 3" even when the desktop stream is the important
      # part. Disable the browser-side audio connection and let video alone
      # mark the session connected.
      substituteInPlace $out/opt/selkies-gstreamer/share/selkies-web/app.js \
        --replace-fail "audio_webrtc.playStream();" "// audio disabled for Bullpen desktop: audio_webrtc.playStream();" \
        --replace-fail "if (videoConnected === \"connected\" && audioConnected === \"connected\") {" "if (videoConnected === \"connected\") {" \
        --replace-fail "app.status = state === \"connected\" ? audioConnected : videoConnected;" "app.status = videoConnected;" \
        --replace-fail "        webrtc.connect();" "        audioConnected = \"disabled\";\n        webrtc.connect();" \
        --replace-fail "        audio_webrtc.connect();" "        // audio disabled for Bullpen desktop: audio_webrtc.connect();" \
        --replace-fail "navigator.serviceWorker.register('./sw.js?ts=1723709107');" "navigator.serviceWorker.getRegistrations().then(regs => regs.forEach(reg => reg.unregister()));"

      substituteInPlace $out/opt/selkies-gstreamer/share/selkies-web/index.html \
        --replace-fail '<video id="stream" class="video" preload="none" disablePictureInPicture="true" playsinline>' '<video id="stream" class="video" tabindex="0" preload="none" disablePictureInPicture="true" playsinline autofocus>'

      makeWrapper $out/opt/selkies-gstreamer/bin/selkies-gstreamer-run $out/bin/selkies-gstreamer-run \
        --prefix PATH : ${lib.makeBinPath [pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.xorg-server pkgs.xrandr]} \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [pkgs.gmp]} \
        --prefix LD_LIBRARY_PATH : $out/opt/selkies-gstreamer/lib/python3.12/site-packages/pillow.libs \
        --set SELKIES_WEB_ROOT $out/opt/selkies-gstreamer/share/selkies-web
      runHook postInstall
    '';
  };

  selkiesSession = pkgs.writeShellScript "bullpen-selkies-session" ''
    set -euo pipefail

    export PATH=${lib.makeBinPath [pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.xorg-server pkgs.xrandr pkgs.xset]}
    unset PYTHONPATH PYTHONHOME
    export PYTHONNOUSERSITE=1
    export HOME=/home/bullpen
    export DISPLAY=${display}
    export XDG_RUNTIME_DIR=/tmp/bullpen-runtime
    export LOGDIR=/workbench/logs
    export ENABLE_XVFB=false
    export ENABLE_PULSEAUDIO=false

    mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$LOGDIR"
    chmod 700 "$XDG_RUNTIME_DIR"

    for _ in $(seq 1 100); do
      if ${pkgs.xset}/bin/xset -display ${display} q >/dev/null 2>&1; then
        break
      fi
      sleep 0.2
    done

    exec ${selkiesPortable}/bin/selkies-gstreamer-run \
      --addr=0.0.0.0 \
      --port=${toString selkiesPort} \
      --enable_https=false \
      --enable_basic_auth=false \
      --encoder=x264enc \
      --enable_resize=false
  '';

  bullpenX11Run = pkgs.writeShellApplication {
    name = "bullpen-x11-run";
    runtimeInputs = [pkgs.systemd];
    text = ''
      if [ "$#" -eq 0 ]; then
        echo "usage: bullpen-x11-run <command> [args...]" >&2
        exit 64
      fi

      exec machinectl shell --quiet --uid=bullpen bullpen-workbench-x11 \
        /run/current-system/sw/bin/env DISPLAY=${display} XDG_RUNTIME_DIR=/tmp/bullpen-runtime "$@"
    '';
  };

  bullpenXdo = pkgs.writeShellApplication {
    name = "bullpen-xdo";
    runtimeInputs = [bullpenX11Run];
    text = ''
      if [ "$#" -eq 0 ]; then
        cat >&2 <<'USAGE'
usage: bullpen-xdo <xdotool args...>
examples:
  bullpen-xdo key ctrl+l
  bullpen-xdo type "hello from Hermes"
  bullpen-xdo click 1
USAGE
        exit 64
      fi
      exec bullpen-x11-run xdotool "$@"
    '';
  };

  bullpenWindows = pkgs.writeShellApplication {
    name = "bullpen-windows";
    runtimeInputs = [bullpenX11Run];
    text = ''
      exec bullpen-x11-run wmctrl -lx
    '';
  };

  bullpenShot = pkgs.writeShellApplication {
    name = "bullpen-shot";
    runtimeInputs = [bullpenX11Run pkgs.coreutils];
    text = ''
      target="''${1:-${sharedDir}/screenshots/latest.png}"
      case "$target" in
        ${sharedDir}/screenshots/*) ;;
        *)
          echo "Refusing to write outside ${sharedDir}/screenshots" >&2
          exit 64
          ;;
      esac

      mkdir -p ${sharedDir}/screenshots
      name="$(basename "$target")"
      bullpen-x11-run maim "/workbench/screenshots/$name"
      echo "$target"
    '';
  };

  bullpenOpenUrl = pkgs.writeShellApplication {
    name = "bullpen-open-url";
    runtimeInputs = [bullpenX11Run];
    text = ''
      if [ "$#" -ne 1 ]; then
        echo "usage: bullpen-open-url <url>" >&2
        exit 64
      fi
      exec bullpen-x11-run firefox --new-tab "$1"
    '';
  };

  openboxSession = pkgs.writeShellScript "bullpen-openbox-session" ''
    set -euo pipefail

    export PATH=${lib.makeBinPath [pkgs.bash pkgs.coreutils pkgs.dbus pkgs.dmenu pkgs.firefox pkgs.fish pkgs.git pkgs.lxpanel pkgs.lxterminal pkgs.mousepad pkgs.openbox pkgs.pcmanfm pkgs.rofi pkgs.starship pkgs.xorg-server pkgs.xset pkgs.xsetroot pkgs.xterm pkgs.zellij]}
    export HOME=/home/bullpen
    export DISPLAY=${display}
    export XDG_RUNTIME_DIR=/tmp/bullpen-runtime

    mkdir -p "$HOME" "$HOME/.config/fish/functions" "$HOME/.config/helix" "$HOME/.config/lxpanel/LXDE/panels" "$HOME/.config/openbox" "$HOME/.config/zellij" "$HOME/.cache" "$HOME/.mozilla/bullpen-profile" "$HOME/.helix" "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"

    rm -f /tmp/.X99-lock /tmp/.X11-unix/X99

    ${pkgs.xorg-server}/bin/Xvfb ${display} \
      -screen 0 1920x1080x24 \
      -nolisten tcp \
      -ac &
    xvfb_pid=$!

    cleanup() {
      kill "$xvfb_pid" 2>/dev/null || true
    }
    trap cleanup EXIT

    for _ in $(seq 1 50); do
      if ${pkgs.xset}/bin/xset -display ${display} q >/dev/null 2>&1; then
        break
      fi
      sleep 0.1
    done

    cat > "$HOME/.config/fish/config.fish" <<'FISHCFG'
    # Bullpen Workbench fish config - mirrors Dale's nixfiles userLevel/fish + home editor env.
    set -gx EDITOR hx
    set -gx VISUAL hx
    set -gx PROMISCUNIX_ROOT /nixfiles

    if status is-interactive
        if test -f ~/.config/starship-user.toml
            set -gx STARSHIP_CONFIG ~/.config/starship-user.toml
        end
        if command -q starship
            starship init fish | source
        end

        function fish_right_prompt
            if command -q starship
                starship module time
            end
        end

        # Source user overrides if present
        if test -f ~/.config/fish/user-overrides.fish
            source ~/.config/fish/user-overrides.fish
        end
    end
    FISHCFG

    cat > "$HOME/.config/fish/user-overrides.fish.template" <<'FISHTEMPLATE'
    # Fish User Overrides
    # Copy this file to ~/.config/fish/user-overrides.fish
    # This file is NOT managed by Nix - customize freely!
    #
    # Examples:
    # set -gx EDITOR hx
    # alias ll "ls -la --color=auto"
    # alias gs "git status"
    # set fish_greeting ""  # Disable greeting
    FISHTEMPLATE

    cat > "$HOME/.config/starship.toml" <<'STARSHIP'
    add_newline = true
    format = '''$username$hostname $time $directory( on $git_branch$git_status)$fill[╭─](bold blue)
    [╰─](bold blue)$character'''

    [character]
    success_symbol = "[❯](bold blue) "
    error_symbol = "[❯](bold red) "
    vicmd_symbol = "[❮](bold yellow) "

    [username]
    show_always = true
    format = "[$user]($style)"
    style_user = "bold mauve"
    style_root = "bold red"

    [hostname]
    ssh_only = false
    ssh_symbol = ""
    format = "[@$hostname]($style)"
    style = "bold sapphire"

    [directory]
    truncate_to_repo = true
    truncation_length = 2

    [git_branch]
    format = "[ $branch]($style)"
    style = "bold purple"

    [git_status]
    format = "[$all_status$ahead_behind]($style)"
    style = "yellow"

    [time]
    disabled = false
    format = "[$time]($style) "
    time_format = "%I:%M %p"
    use_12hr = true
    utc_time_offset = "local"
    style = "bold dimmed mauve"

    palette = "catppuccin_mocha"
    [palettes.catppuccin_mocha]
    rosewater = "#f5e0dc"
    flamingo = "#f2cdcd"
    pink = "#f5c2e7"
    mauve = "#cba6f7"
    red = "#f38ba8"
    maroon = "#eba0ac"
    peach = "#fab387"
    yellow = "#f9e2af"
    green = "#a6e3a1"
    teal = "#94e2d5"
    sky = "#89dceb"
    sapphire = "#74c7ec"
    blue = "#89b4fa"
    lavender = "#b4befe"
    text = "#cdd6f4"
    subtext1 = "#bac2de"
    subtext0 = "#a6adc8"
    overlay2 = "#9399b2"
    overlay1 = "#7f849c"
    overlay0 = "#6c7086"
    surface2 = "#585b70"
    surface1 = "#45475a"
    surface0 = "#313244"
    base = "#1e1e2e"
    mantle = "#181825"
    crust = "#11111b"
    STARSHIP

    cat > "$HOME/.config/helix/config.toml" <<'HELIXCFG'
    theme = "catppuccin_mocha"
    HELIXCFG

    cat > "$HOME/.config/helix/languages.toml" <<HELIXLANG
    [language-server.nil]
    command = "${pkgs.nil}/bin/nil"

    [[language]]
    name = "nix"
    auto-format = true
    language-servers = ["nil"]
    formatter = { command = "${pkgs.alejandra}/bin/alejandra", args = ["-qq"] }
    HELIXLANG

    cat > "$HOME/.config/helix/README-overrides.md" <<'HELIXREADME'
    # Helix User Customization

    This mirrors Dale's nixfiles `modules/userLevel/helix` defaults.
    Helix merges configuration from multiple sources:
    1. Built-in defaults
    2. ~/.config/helix/config.toml
    3. ~/.helix/config.toml
    4. .helix/config.toml
    HELIXREADME

    cat > "$HOME/.config/zellij/config.kdl" <<'ZELLIJCFG'
    // Zellij Configuration - Managed by Bullpen Workbench from Dale's nixfiles userLevel/zellij defaults.
    plugins {
      tab-bar { path "tab-bar"; }
      status-bar { path "status-bar"; }
    }

    theme "catppuccin-mocha"
    ZELLIJCFG

    cat > "$HOME/.config/zellij/user-overrides.kdl.template" <<'ZELLIJTEMPLATE'
    // Zellij User Overrides
    // Copy ideas from here if you later make this workbench stateful/user-editable.
    // theme "gruvbox-dark"
    ZELLIJTEMPLATE

    cat > "$HOME/.config/openbox/menu.xml" <<'MENUXML'
    <?xml version="1.0" encoding="UTF-8"?>
    <openbox_menu xmlns="http://openbox.org/3.4/menu">
      <menu id="root-menu" label="Bullpen">
        <item label="Terminal"><action name="Execute"><command>${pkgs.lxterminal}/bin/lxterminal -e ${pkgs.fish}/bin/fish</command></action></item>
        <item label="Terminal + Zellij"><action name="Execute"><command>${pkgs.lxterminal}/bin/lxterminal --title='Bullpen Workbench' -e ${pkgs.fish}/bin/fish -lc '${pkgs.zellij}/bin/zellij -s bullpen'</command></action></item>
        <item label="Firefox"><action name="Execute"><command>${pkgs.firefox}/bin/firefox --no-remote --profile /home/bullpen/.mozilla/bullpen-profile</command></action></item>
        <item label="Files: /workbench"><action name="Execute"><command>${pkgs.pcmanfm}/bin/pcmanfm /workbench</command></action></item>
        <item label="Text Editor"><action name="Execute"><command>${pkgs.mousepad}/bin/mousepad</command></action></item>
        <item label="App Launcher"><action name="Execute"><command>${pkgs.rofi}/bin/rofi -show drun</command></action></item>
        <separator />
        <item label="Reconfigure Openbox"><action name="Reconfigure" /></item>
        <item label="Restart Openbox"><action name="Restart" /></item>
      </menu>
    </openbox_menu>
    MENUXML

    cat > "$HOME/.config/openbox/rc.xml" <<'RCXML'
    <?xml version="1.0" encoding="UTF-8"?>
    <openbox_config xmlns="http://openbox.org/3.4/rc">
      <theme><name>Clearlooks</name><titleLayout>NLIMC</titleLayout></theme>
      <desktops><number>1</number><firstdesk>1</firstdesk><names><name>Workbench</name></names></desktops>
      <resize><drawContents>yes</drawContents></resize>
      <focus><focusNew>yes</focusNew><followMouse>no</followMouse><raiseOnFocus>no</raiseOnFocus></focus>
      <keyboard>
        <keybind key="W-Return"><action name="Execute"><command>${pkgs.lxterminal}/bin/lxterminal -e ${pkgs.fish}/bin/fish</command></action></keybind>
        <keybind key="W-t"><action name="Execute"><command>${pkgs.lxterminal}/bin/lxterminal -e ${pkgs.fish}/bin/fish</command></action></keybind>
        <keybind key="W-f"><action name="Execute"><command>${pkgs.firefox}/bin/firefox --no-remote --profile /home/bullpen/.mozilla/bullpen-profile</command></action></keybind>
        <keybind key="W-e"><action name="Execute"><command>${pkgs.pcmanfm}/bin/pcmanfm /workbench</command></action></keybind>
        <keybind key="W-space"><action name="Execute"><command>${pkgs.rofi}/bin/rofi -show drun</command></action></keybind>
        <keybind key="A-F2"><action name="Execute"><command>${pkgs.rofi}/bin/rofi -show run</command></action></keybind>
        <keybind key="A-Tab"><action name="NextWindow" /></keybind>
        <keybind key="A-F4"><action name="Close" /></keybind>
      </keyboard>
      <mouse>
        <context name="Root"><mousebind button="Right" action="Press"><action name="ShowMenu"><menu>root-menu</menu></action></mousebind></context>
      </mouse>
      <menu><file>menu.xml</file></menu>
    </openbox_config>
    RCXML

    cat > "$HOME/.config/lxpanel/LXDE/panels/panel" <<'PANEL'
    Global {
      edge=bottom
      allign=center
      margin=0
      widthtype=percent
      width=100
      height=36
      transparent=0
      tintcolor=#111827
      alpha=255
      setdocktype=1
      setpartialstrut=1
      usefontcolor=1
      fontcolor=#f8fafc
      background=0
    }
    Plugin { type=menu Config { name=Bullpen image=start-here } }
    Plugin { type=launchbar Config { Button { id=firefox.desktop } Button { id=pcmanfm.desktop } Button { id=lxterminal.desktop } } }
    Plugin { type=taskbar Config { tooltips=1 IconsOnly=0 ShowAllDesks=1 UseMouseWheel=1 } }
    Plugin { type=tray Config {} }
    Plugin { type=dclock Config { ClockFmt=%H:%M } }
    PANEL

    cat > "$HOME/.gtkrc-2.0" <<'GTKRC'
    gtk-theme-name="Adwaita"
    gtk-icon-theme-name="Adwaita"
    gtk-font-name="Sans 11"
    GTKRC

    cat > "$HOME/.config/openbox/autostart" <<'AUTOSTART'
    ${pkgs.xsetroot}/bin/xsetroot -solid '#0b1020' &
    ${pkgs.pcmanfm}/bin/pcmanfm --desktop --profile LXDE &
    ${pkgs.lxpanel}/bin/lxpanel --profile LXDE &
    ${pkgs.pcmanfm}/bin/pcmanfm /workbench &
    ${pkgs.lxterminal}/bin/lxterminal --title='Bullpen Workbench' --geometry=120x32 -e ${pkgs.fish}/bin/fish -lc 'printf "Bullpen Openbox/Xvfb session ready.\\nDISPLAY=:99\\nShared folder: /workbench\\nNixfiles mounted read-only: /nixfiles\\nShell/editor stack: fish + starship, hx, zellij\\n\\nShortcuts:\\n  Super+Enter / Super+t = Terminal\\n  Super+f = Firefox\\n  Super+e = Files\\n  Super+Space = Launcher\\n  Right-click desktop = Menu\\n\\n"; exec ${pkgs.zellij}/bin/zellij -s bullpen' || ${pkgs.xterm}/bin/xterm -fa 'Monospace' -fs 14 -bg white -fg black -geometry 120x32+40+60 -title 'Bullpen Workbench' -e ${pkgs.fish}/bin/fish -lc 'printf "Bullpen Openbox/Xvfb session ready.\\nDISPLAY=:99\\nShared folder: /workbench\\n"; exec ${pkgs.zellij}/bin/zellij -s bullpen' &
    ${pkgs.firefox}/bin/firefox --no-remote --profile /home/bullpen/.mozilla/bullpen-profile about:blank &
    AUTOSTART

    exec ${pkgs.openbox}/bin/openbox-session
  '';
in {
  # Host-side control surface. This is intentionally outside the GUI container so
  # it stays reachable even if the disposable X11 session is restarted/reset.
  systemd.tmpfiles.rules = [
    "d /var/lib/bullpen-workbench 0770 root users -"
    "d ${dataDir} 0750 root root -"
    "d ${sharedDir} 0770 root users -"
    "d ${sharedDir}/screenshots 0770 root users -"
    "d ${sharedDir}/logs 0770 root users -"
  ];

  systemd.services.bullpen-workbench = {
    description = "Bullpen Workbench control surface";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    environment = {
      BULLPEN_WORKBENCH_TITLE = "Bullpen Workbench";
      BULLPEN_WORKBENCH_DATA = dataDir;
      BULLPEN_WORKBENCH_SELKIES_URL = "http://127.0.0.1:${toString selkiesPort}";
      BULLPEN_WORKBENCH_OBSIDIAN_NOTE = "/home/damajha/Documents/Obsidian/03 Canonical/Projects/Hermes Shared Desktop Workbench.md";
      BULLPEN_WORKBENCH_REDIRECT_TO_SELKIES = "false";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${package}/bin/bullpen-workbench --host 0.0.0.0 --port ${toString workbenchPort}";
      Restart = "always";
      RestartSec = 2;
      DynamicUser = false;
      User = "root";
      WorkingDirectory = dataDir;
    };
  };

  # Keep the unauthenticated LAN prototype off Tailscale and other interfaces.
  # Remote access should enter through the authenticated Pangolin front door.
  networking.firewall.interfaces.${systemInfo.networkInterfaceName}.allowedTCPPorts = [workbenchPort selkiesPort];

  environment.systemPackages = [
    bullpenX11Run
    bullpenXdo
    bullpenWindows
    bullpenShot
    bullpenOpenUrl
  ];

  # NixOS containers are systemd-nspawn containers. This container hosts the
  # disposable X11/Openbox desktop that Selkies will stream in the next slice.
  containers.bullpen-workbench-x11 = {
    autoStart = true;
    ephemeral = false;
    privateNetwork = false;

    bindMounts = {
      "/workbench" = {
        hostPath = sharedDir;
        isReadOnly = false;
      };
      "/nixfiles" = {
        hostPath = "/home/damajha/nixfiles";
        isReadOnly = true;
      };
    };

    config = {pkgs, ...}: {
      system.stateVersion = "25.05";

      users.users.bullpen = {
        isNormalUser = true;
        uid = 2100;
        group = "bullpen";
        home = "/home/bullpen";
        createHome = true;
        shell = pkgs.fish;
        extraGroups = ["users"];
      };
      users.groups.bullpen.gid = 2100;

      services.dbus.enable = true;
      programs.fish.enable = true;

      environment.systemPackages = with pkgs; [
        firefox
        fish
        git
        starship
        nil
        alejandra
        bat
        dbus
        imagemagick
        maim
        mousepad
        kitty
        lxpanel
        lxterminal
        openbox
        pcmanfm
        rofi
        dmenu
        adwaita-icon-theme
        wmctrl
        xclip
        xdotool
        xterm
        helix
        zellij
        xprop
        xwininfo
        xorg-server
        xrandr
        xset
        xsetroot
      ];

      systemd.services.bullpen-x11-session = {
        description = "Disposable Bullpen Xvfb/Openbox desktop";
        wantedBy = ["multi-user.target"];
        after = ["dbus.service"];
        serviceConfig = {
          Type = "simple";
          User = "bullpen";
          Group = "bullpen";
          ExecStart = openboxSession;
          Restart = "always";
          RestartSec = 2;
        };
      };

      systemd.services.bullpen-selkies = {
        description = "Selkies stream for Bullpen X11 desktop";
        wantedBy = ["multi-user.target"];
        after = ["bullpen-x11-session.service"];
        wants = ["bullpen-x11-session.service"];
        environment = {
          DISPLAY = display;
        };
        serviceConfig = {
          Type = "simple";
          User = "bullpen";
          Group = "bullpen";
          ExecStart = selkiesSession;
          Restart = "always";
          RestartSec = 3;
        };
      };
    };
  };
}
