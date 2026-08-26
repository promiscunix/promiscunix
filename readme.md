# Promiscunix

Promiscunix is my ongoing attempt at a scalable NixOS layout for managing multiple machines and multiple users without copy/paste. It’s built like a hobby project because it is one: I’m experimenting, learning, and trying to keep the pieces understandable enough that other people can fork it and make it their own.

The headline idea is simple:

- Users are defined once (in `users/*/userInfo.toml`)
- Hosts are defined once (in `hosts/*/systemInfo.toml`)
- A host “picks up” users automatically when roles match

Everything else (apps, services, UI choices) is just modules you import per host or per user.

## What this repo is trying to solve

If you run more than one NixOS machine, you end up asking questions like:

- Which users should exist on which machines?
- How do I keep user config consistent without turning every machine into a snowflake?
- How do I safely rebuild remote hosts without leaving SSH wide open?
- How do I add services cleanly without turning `configuration.nix` into a dump?

Promiscunix is my answer: role-based user provisioning, a small host “factory”, and a bunch of modules that you can mix and match.

## Design overview

## Repository map (quick navigation)

- `flake.nix` — flake inputs and host factory (`mkHost`)
- `hosts/<name>/` — per-host system definitions (`systemInfo.toml`, `configuration.nix`, hardware files)
- `users/<name>/` — user identity + Home Manager entrypoints (`userInfo.toml`, `home.nix`)
- `modules/core/` — baseline modules imported by hosts
- `modules/systemLevel/` — machine/service modules (networking, services, optimization)
- `modules/userLevel/` — user-space modules (shell/editor/UI tooling)
- `.sops.yaml` — SOPS rules and key mappings
- `PROJECT.md` — operator/deployment guide and architecture quick reference


### 1) Role-based users and hosts (the core idea)

- Each user lives in `users/<name>/userInfo.toml` and has roles like `workstation` or `admin`.
- Each host lives in `hosts/<name>/systemInfo.toml` and declares which roles it wants.
- `modules/systemLevel/accounts/default.nix` matches roles and creates:
  - system accounts (`users.users.*`)
  - Home Manager configs for those users (`home-manager.users.*`)

The result is that adding a user or changing a user’s shell/keys propagates to every host that selects them.

### 2) A host factory (flake output)

`flake.nix`:

- scans `users/*/userInfo.toml` into one `userInfos` database
- reads each host’s `hosts/<name>/systemInfo.toml`
- passes `systemInfo` and `userInfos` into modules via `specialArgs`

Hosts are still explicitly listed in `flake.nix` (on purpose). I like that being “a host exists” is obvious and greppable.

### 3) Modules, split by “system” vs “user”

- `modules/core/`: baseline config imported by every host
- `modules/systemLevel/`: system services and machine-level configuration (NAS, arr stack, Guacamole, xrdp, etc.)
- `modules/userLevel/`: Home Manager modules for user programs (fish, helix, starship, zellij, hyprland, etc.)

### 4) “User overrides” without rebuilding (a small hack I like)

Several user-level modules end by sourcing a file that Home Manager does not overwrite, for example:

- fish: `~/.config/fish/user-overrides.fish`
- hyprland: `~/.config/hypr/user-overrides.conf`
- starship: `~/.config/starship-user.toml` (full replacement)

This is deliberate: it gives you a safe escape hatch for quick tweaks without turning your flake into a constant rebuild machine.

### 5) Remote-first + Tailscale-first

This repo is opinionated about remote management:

- SSH password auth is disabled.
- SSH is allowed via Tailscale (`tailscale0`) by default.
- Services that expose ports are generally scoped to `tailscale0` (not LAN).
- A bootstrap option exists if you need a temporary “first rebuild” path.

I’m optimizing for “I can rebuild my servers remotely without regretting it later”.

### 6) Optimization modules

The `modules/systemLevel/optimize/` structure is meant to be boring, reusable “hardware hygiene”:

- `optimize/shared`: defaults I like on most machines (tools, fwupd, thermals, zram, nix gc/optimise, trim, smartd)
- `optimize/<machine>`: machine-specific tweaks (e.g. GPU/QuickSync bits)

One small but useful pattern: zram defaults can be overridden per machine with `lib.mkDefault`.

### 7) `modules/systemLevel/testing` is a scratchpad

`modules/systemLevel/testing/default.nix` is where I drop random packages while I’m trying things out. It’s intentionally messy and temporary.

If you’re forking this repo, you probably want to:

- remove it from `modules/core/default.nix` on “server” machines, or
- split the packages into proper modules as you stabilize them

This repo supports a simple host profile (`systemInfo.profile = "server"`) that skips `testing` and skips user Hyprland.

## Try it safely: the included VM

There is a `virtnix` host intended for experimenting.

Build the VM:
```bash
nixos-rebuild build-vm --flake .#virtnix
```

Run the VM using the generated script in `./result` (Nix prints the command after build).

## Getting started (forking this repo)

### Prereqs

- NixOS (or a machine that can run `nixos-rebuild` against a target)
- Flakes enabled (`nix.settings.experimental-features = ["nix-command" "flakes"]`)

### 1) Create a user

Create:

- `users/<name>/userInfo.toml`
- `users/<name>/home.nix`

Example `userInfo.toml`:
```toml
fullName = "Alice Example"
email    = "alice@example.com"
userName = "alice"
shell    = "fish"
roles    = ["workstation"]
sshKeys  = ["ssh-ed25519 AAAA..."]
```

### 2) Create a host

Create:

- `hosts/<name>/systemInfo.toml`
- `hosts/<name>/configuration.nix`
- `hosts/<name>/hardware-configuration.nix` (generated on the target machine)

Example `systemInfo.toml`:
```toml
hostName = "myhost"
mainUser = "alice"
profile = "server" # optional: "server" skips GUI scratchpad packages

[accounts]
includeRoles = ["workstation"]
wheelRole = "admin"
```

### 3) Add the host to `flake.nix`

Add it to `nixosConfigurations`:
```nix
myhost = mkHost "myhost";
```

## Rebuilding remotely

### Plain `nixos-rebuild`

```bash
nixos-rebuild switch \
  --flake .#<hostname> \
  --target-host root@<host>
```

Use a stable Tailscale IP for `<host>` when Tailscale DNS acceptance is disabled.

### Fish shortcut: `nrs`

There’s a fish helper function that resolves the host from `tailscale status`
and runs the rebuild against its Tailscale IP without changing system DNS.

```fish
set -gx PROMISCUNIX_ROOT /path/to/nixfiles
nrs theLibrary
```

The source machine must be connected to the tailnet and able to run
`tailscale status`; MagicDNS is not required.

## Remote install flow (Tailscale-first)

This is the “don’t lock yourself out” way I’ve been using when provisioning a new remote host from a desktop.

1) Generate a Tailscale auth key (recommended: reusable + tagged).

2) Store it with SOPS:
```bash
cd /path/to/nixfiles
nix-shell -p sops --run "SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys-desktop.txt sops secrets/tailscale.yaml"
```
Decrypted content:
```yaml
tailscale_authkey: tskey-xxxxxxxxxxxxxxxxxxxx
```

3) Temporarily allow LAN SSH for the first rebuild on the new host:
```nix
promiscunix.tailscale.bootstrapSsh = true;
```

4) Copy the SOPS age key onto the new host so it can decrypt secrets:
```bash
ssh root@<lan-ip> "sudo mkdir -p /var/lib/sops-nix && sudo chmod 700 /var/lib/sops-nix"
cat ~/.config/sops/age/keys-desktop.txt | \
  ssh root@<lan-ip> "sudo tee /var/lib/sops-nix/key.txt > /dev/null && sudo chmod 600 /var/lib/sops-nix/key.txt"
```

5) Rebuild once over LAN SSH:
```bash
nixos-rebuild switch --flake .#<hostname> --target-host root@<lan-ip>
```

6) Once the host shows up in your tailnet, remove `bootstrapSsh` and rebuild again to lock SSH to Tailscale.

## Notes and disclaimers

- This is not a “framework”, it’s a pile of patterns I’m actively refining.
- The service modules reflect my lab. Fork and adapt aggressively.
- Secrets are expected to be SOPS-encrypted; don’t commit plaintext secrets.
