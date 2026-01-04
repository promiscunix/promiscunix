{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.transcodeHevc;

  transcodeScript = pkgs.writeScriptBin "transcode-hevc" ''
    #!${pkgs.python3}/bin/python
    import argparse, subprocess, sys, shlex, json
    from pathlib import Path

    FFMPEG  = "${pkgs.ffmpeg}/bin/ffmpeg"
    FFPROBE = "${pkgs.ffmpeg}/bin/ffprobe"

    # Injected from Nix as Python literals
    DEFAULT_EXTS = ${builtins.toJSON cfg.extensions}
    SCALE_W      = ${toString cfg.scaleWidth}
    SCALE_H      = ${toString cfg.scaleHeight}
    PRESET       = "${cfg.preset}"
    CRF          = ${toString cfg.crf}
    AUDIO_BR     = "${cfg.audioBitrate}"
    FORCE_STEREO = ${
      if cfg.stereo
      then "True"
      else "False"
    }
    MIN_SIZE_MB  = ${toString cfg.minSizeMB}

    def is_video(path: Path, exts):
      return path.is_file() and path.suffix.lower() in exts

    def mb(size_bytes):
      return size_bytes / (1024 * 1024)

    def ffprobe_streams(path: Path):
      """Return (v, a): first video and first audio stream dicts (or None)."""
      def probe(sel):
        cmd = [
          FFPROBE, "-v", "error", "-select_streams", sel,
          "-show_entries", "stream=codec_name,pix_fmt,width,height,channels,bit_rate",
          "-of", "json", str(path)
        ]
        p = subprocess.run(cmd, capture_output=True, text=True)
        if p.returncode != 0:
          return None
        try:
          data = json.loads(p.stdout)
          arr = data.get("streams", [])
          return arr[0] if arr else None
        except Exception:
          return None
      return probe("v:0"), probe("a:0")

    def is_compliant(path: Path):
      """Spec: HEVC + yuv420p, <=1080p, AAC stereo."""
      v, a = ffprobe_streams(path)
      if not v or not a:
        return False, "missing-streams"

      # Video checks
      v_codec = v.get("codec_name")
      v_pix   = v.get("pix_fmt")
      w_raw   = v.get("width")
      h_raw   = v.get("height")
      try:
        w = int(w_raw); h = int(h_raw)
      except Exception:
        return False, "video-dimension"

      if not (v_codec == "hevc" and v_pix == "yuv420p"):
        return False, "video-codec-or-pixfmt"
      if w > SCALE_W or h > SCALE_H:
        return False, "video-dimension"

      # Audio checks
      a_codec = a.get("codec_name")
      try:
        chans = int(a.get("channels", 0))
      except Exception:
        chans = 0
      if not (a_codec == "aac" and chans == 2):
        return False, "audio"

      return True, "ok"

    def build_ffmpeg_cmd(inp: Path, outp: Path):
      # Ensure final encoder input has EVEN dimensions and normalized SAR.
      vf = f"scale={SCALE_W}:{SCALE_H}:force_original_aspect_ratio=decrease,scale=ceil(iw/2)*2:ceil(ih/2)*2,setsar=1"
      cmd = [
        FFMPEG, "-hide_banner", "-y", "-nostdin",
        "-i", str(inp),
        "-map", "0:v:0", "-map", "0:a:0", "-map", "0:s?",
        "-vf", vf,
        "-c:v", "libx265", "-preset", PRESET, "-crf", str(CRF), "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", AUDIO_BR
      ]
      if FORCE_STEREO:
        cmd += ["-ac", "2"]
      cmd += [
        "-c:s", "srt",
        "-map_metadata", "0", "-map_chapters", "0",
        "-movflags", "+faststart",
        "-f", "matroska",            # keep container correct even with .partial in name
        str(outp)
      ]
      return cmd

    def transcode_one(inp: Path, out_final: Path, dry_run: bool):
      # Write temp as "<stem>.partial.mkv" so .mkv is the last suffix
      tmp = out_final.with_name(out_final.stem + ".partial" + out_final.suffix)
      cmd = build_ffmpeg_cmd(inp, tmp)
      if dry_run:
        print(shlex.join(cmd))
        return 0

      proc = subprocess.run(cmd)
      if proc.returncode != 0:
        # Clean partial if present
        try:
          if tmp.exists():
            tmp.unlink()
        except Exception:
          pass
        return proc.returncode

      # Atomic-ish finalize
      try:
        if out_final.exists():
          out_final.unlink()
      except Exception:
        pass
      tmp.rename(out_final)
      return 0

    def plan_output(inp: Path):
      return inp.with_name(inp.stem + ".hevc-aac.mkv")

    def walk_files(root: Path, exts):
      for p in root.rglob("*"):
        if is_video(p, exts):
          yield p

    def run():
      ap = argparse.ArgumentParser(description="Transcode file or directory tree to HEVC/AAC 1080p if non-compliant.")
      ap.add_argument("path", help="Input file or directory")
      ap.add_argument("--out", help="Output file (only if input is a single file)")
      ap.add_argument("--ext", action="append", help="Extra video extensions (e.g. --ext .mkv --ext .mp4)")
      ap.add_argument("--min-size-mb", type=int, default=MIN_SIZE_MB, help=f"Skip files smaller than this (default {MIN_SIZE_MB} MB)")
      ap.add_argument("--replace", action="store_true", help="Delete original after successful transcode")
      ap.add_argument("--dry-run", action="store_true", help="Print actions/commands without executing")
      args = ap.parse_args()

      target = Path(args.path).expanduser().resolve()
      if not target.exists():
        print(f"Input not found: {target}", file=sys.stderr); sys.exit(2)

      exts = set(DEFAULT_EXTS)
      if args.ext:
        exts |= {e.lower() if e.startswith(".") else "."+e.lower() for e in args.ext}

      total = checked = transcoded = skipped = deleted = 0
      failures = 0

      # Size accounting (for files actually encoded this run)
      bytes_orig_encoded = 0
      bytes_new_encoded  = 0

      def handle_file(f: Path):
        nonlocal total, checked, transcoded, skipped, deleted, failures
        nonlocal bytes_orig_encoded, bytes_new_encoded
        total += 1

        # Size filter
        try:
          if mb(f.stat().st_size) < args.min_size_mb:
            print(f"skip (too small): {f}")
            skipped += 1; return
        except Exception:
          pass

        compliant, reason = is_compliant(f)
        checked += 1
        if compliant:
          print(f"ok (compliant): {f}")
          skipped += 1
          return

        outp = plan_output(f) if not args.out else Path(args.out).expanduser().resolve()
        if outp.exists():
          print(f"skip (exists): {outp}")
          skipped += 1
          return

        # Grab original size BEFORE running (in case we --replace)
        try:
          orig_bytes = f.stat().st_size
        except Exception:
          orig_bytes = None

        print(f"transcode ({reason}): {f} -> {outp}")
        rc = transcode_one(f, outp, args.dry_run)
        if rc == 0:
          if not args.dry_run:
            transcoded += 1
            # Add size stats if we can read them
            try:
              new_bytes = outp.stat().st_size
            except Exception:
              new_bytes = None

            if orig_bytes is not None and new_bytes is not None:
              bytes_orig_encoded += orig_bytes
              bytes_new_encoded  += new_bytes
              saved = orig_bytes - new_bytes
              pct = (saved / orig_bytes * 100.0) if orig_bytes > 0 else 0.0
              print(f"done: size {mb(orig_bytes):.2f} MB -> {mb(new_bytes):.2f} MB (saved {mb(saved):.2f} MB, {pct:.1f}%)")

            if args.replace:
              try:
                f.unlink()
                deleted += 1
              except Exception as e:
                print(f"warn: failed to delete original {f}: {e}", file=sys.stderr)
        else:
          failures += 1
          print(f"ERROR: ffmpeg failed on {f} (rc={rc})", file=sys.stderr)

      if target.is_file():
        handle_file(target)
      else:
        for f in walk_files(target, exts):
          handle_file(f)

      print("--- summary ---")
      print(f"total found:   {total}")
      print(f"checked:       {checked}")
      print(f"transcoded:    {transcoded}")
      print(f"skipped:       {skipped}")
      print(f"deleted origs: {deleted}")
      print(f"failures:      {failures}")

      # Size summary only for files actually encoded in this run
      if bytes_orig_encoded > 0:
        saved_bytes = bytes_orig_encoded - bytes_new_encoded
        pct = (saved_bytes / bytes_orig_encoded * 100.0) if bytes_orig_encoded > 0 else 0.0
        print("--- size summary (encoded this run) ---")
        print(f"original: {mb(bytes_orig_encoded):.2f} MB")
        print(f"new:      {mb(bytes_new_encoded):.2f} MB")
        print(f"saved:    {mb(saved_bytes):.2f} MB ({pct:.1f}%)")

      if failures:
        sys.exit(1)

    if __name__ == "__main__":
      run()
  '';
in {
  options.services.transcodeHevc = {
    enable = lib.mkEnableOption "Install a HEVC/AAC 1080p transcoder CLI (single file or recursive).";

    preset = lib.mkOption {
      type = lib.types.enum ["ultrafast" "superfast" "veryfast" "faster" "fast" "medium" "slow" "slower" "veryslow"];
      default = "medium";
      description = "x265 preset (speed vs compression).";
    };

    crf = lib.mkOption {
      type = lib.types.int;
      default = 23;
      description = "x265 CRF (lower = higher quality, larger files).";
    };

    audioBitrate = lib.mkOption {
      type = lib.types.str;
      default = "160k";
      description = "AAC audio bitrate.";
    };

    stereo = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Force stereo downmix (-ac 2).";
    };

    scaleWidth = lib.mkOption {
      type = lib.types.int;
      default = 1920;
      description = "Max width for scaling.";
    };

    scaleHeight = lib.mkOption {
      type = lib.types.int;
      default = 1080;
      description = "Max height for scaling.";
    };

    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [".mkv" ".mp4" ".mov" ".m4v" ".avi" ".ts" ".wmv"];
      description = "File extensions to scan (lowercase, include the dot).";
    };

    minSizeMB = lib.mkOption {
      type = lib.types.int;
      default = 50;
      description = "Skip files smaller than this many MB.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      transcodeScript
      pkgs.ffmpeg
      pkgs.python3
    ];
  };
}
