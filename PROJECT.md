# Project Guide


## Build & Deployment Commands

```bash
# Build VM for testing (quick iteration)
nixos-rebuild build-vm --flake .#virtnix

# Build and activate on local host
sudo nixos-rebuild switch --flake .#<hostname>

# Deploy to remote host
nixos-rebuild switch \
  --flake .#<hostname> \
  --target-host <user>@<ip> \
  --build-host <user>@<ip> \
  --use-remote-sudo

# Update flake inputs
nix flake update

# Check flake validity
nix flake check
```

## Architecture Overview

This is **Promiscunix** - a role-based NixOS configuration system that automatically provisions users across hosts based on role matching.

### Core Flow

1. **flake.nix** discovers all users by scanning `users/*/userInfo.toml` files
2. **mkHost** function creates NixOS configurations, passing the `userInfos` database to all modules
3. **modules/systemLevel/accounts/default.nix** implements role matching: users are installed on a host if their roles intersect with the host's `includeRoles`

### Key Directories

- `hosts/<name>/` - Host configurations with `systemInfo.toml`, `configuration.nix`, `hardware-configuration.nix`
- `users/<name>/` - User definitions with `userInfo.toml` and `home.nix` (Home Manager config)
- `modules/core/` - Base system configuration (always imported)
- `modules/systemLevel/` - System-wide services (selectively imported per host)
- `modules/userLevel/` - Home Manager modules (fish, helix, starship, zellij, hyprland, etc.)

### User Customization (Without Flake Access)

Users can customize their configs without modifying the flake by editing override files that are sourced by the Nix-managed configs.

| Program | Override File | Type | Apply Changes |
|---------|--------------|------|---------------|
| **Fish** | `~/.config/fish/user-overrides.fish` | Sourced (additive) | Open new terminal |
| **Hyprland** | `~/.config/hypr/user-overrides.conf` | Sourced (additive) | `$mod+R` or `hyprctl reload` |
| **Starship** | `~/.config/starship-user.toml` | Full replacement | Open new terminal |
| **Helix** | `~/.helix/config.toml` | Merged over base | Restart helix |
| **Zellij** | N/A (pending upstream) | See config comments | Restart zellij |

**How it works:**
- Nix-managed configs provide sensible defaults
- At the end of each config, a user-controlled file is sourced (if it exists)
- Users edit the override file freely - Nix never overwrites it (`force = false`)
- Template files (`*.template`) are created showing example customizations

**Hyprland monitor example** - On a desktop with 3 monitors, create `~/.config/hypr/user-overrides.conf`:
```
monitor = DP-1, 2560x1440@144, 0x0, 1
monitor = DP-2, 2560x1440@144, 2560x0, 1
monitor = HDMI-A-1, 1920x1080, 5120x0, 1
```
On a laptop, leave the file empty (auto-detect) or specify the built-in display.

### TOML Configuration Files

**userInfo.toml** defines user identity and roles:
```toml
fullName = "Name"
userName = "username"
shell = "fish"
editor = "helix"
roles = ["workstation", "admin"]
```

**systemInfo.toml** defines host identity and role requirements:
```toml
hostName = "hostname"
mainUser = "username"

[accounts]
includeRoles = ["workstation"]  # Users with these roles are installed
wheelRole = "admin"             # Role that grants sudo access
```

### Special Arguments Available to Modules

- `inputs` - Flake inputs
- `systemInfo` - Current host's parsed systemInfo.toml
- `userInfos` - Database of all users' userInfo.toml files
- `userInfo` - Current user's info (for main user contexts)
- `repoRoot` - Path to repository root

### Role Matching Rules

- Users are selected if any of their roles appear in the host's `includeRoles`
- `includeRoles = ["*"]` installs all users
- `mainUser` is always installed regardless of roles
- Wheel (sudo) access granted if: user is mainUser, has `admin=true`, or has the `wheelRole`
- Shells are only enabled if at least one selected user needs them

### Current Hosts

| Host | Purpose |
|------|---------|
| optiplex | Workstation with Hyprland |
| MTAC | Media center (Jellyfin, *arr stack, Dispatcharr) |
| theBullpen | Desktop with Hyprland |
| TheTheater | Desktop |
| virtnix | VM for testing |

### Secrets Management

Uses SOPS with age encryption. Configuration in `.sops.yaml`.

**Key locations:**
- `.sops.yaml` - Defines which public keys can decrypt which files
- `~/.config/sops/age/keys-desktop.txt` - Your private key (never in git)
- `/var/lib/sops-nix/key.txt` - Host's private key for runtime decryption

**Edit encrypted secrets:**
```bash
cd /path/to/nixfiles
nix-shell -p sops --run "SOPS_AGE_KEY_FILE=\$HOME/.config/sops/age/keys-desktop.txt sops <path-to-secret.yaml>"
```

**Add a new host's key to `.sops.yaml`:**
1. Get host's public key: `ssh <host> "sudo cat /etc/ssh/ssh_host_ed25519_key.pub" | nix-shell -p ssh-to-age --run ssh-to-age`
2. Add to `.sops.yaml` under `keys:` and in `creation_rules`
3. Re-encrypt: `sops updatekeys <path-to-secret.yaml>`

### Guacamole + xrdp (Remote Desktop)

Web-based remote desktop gateway using Apache Guacamole with xrdp backend.

**Modules:**
- `modules/systemLevel/guacamole/` - Guacamole server/client with SOPS secrets
- `modules/systemLevel/xrdp/` - Plasma 6 desktop over RDP (X11 required)

**To enable on a host:**
```nix
imports = [
  (mod "guacamole")
  (mod "xrdp")
];
```

**Access:** `http://<host-ip>:8081/guacamole/`

**Credentials:** Stored in `modules/systemLevel/guacamole/secrets/user-mapping.yaml` (SOPS encrypted)

**To deploy to a new host:**
1. Add host's age public key to `.sops.yaml`
2. Re-encrypt secrets: `sops updatekeys modules/systemLevel/guacamole/secrets/user-mapping.yaml`
3. Copy age key to host: `ssh <host> "sudo mkdir -p /var/lib/sops-nix && sudo tee /var/lib/sops-nix/key.txt > /dev/null && sudo chmod 600 /var/lib/sops-nix/key.txt" < ~/.config/sops/age/keys-desktop.txt`
4. Import modules in host's `configuration.nix`
5. Deploy: `nixos-rebuild switch --flake .#<hostname> ...`
