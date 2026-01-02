# NixOS Impermanence

Research and planning notes for implementing impermanence in Promiscunix.

## What Is Impermanence?

The core concept from Graham Christensen's ["Erase Your Darlings"](https://grahamc.com/blog/erase-your-darlings/): **invert the default**. Instead of accumulating state and occasionally cleaning up, you start fresh every boot and explicitly opt-in to what persists.

NixOS only needs `/boot` and `/nix` to function—everything else is technically ephemeral. Impermanence formalizes this by:

1. Wiping root (`/`) on every boot (via tmpfs, Btrfs snapshot rollback, or ZFS)
2. Bind-mounting persistent paths from a dedicated volume
3. Forcing you to declare what state matters

## Why Consider It?

**Pros:**
- Eliminates undocumented system drift ("works on my machine" issues)
- Forces explicit declaration of all state—aligns with Nix philosophy
- Clean system on every boot ("new computer smell")
- Makes testing VMs truly fresh each time
- Catches missing persistence early (if something breaks after reboot, you forgot to persist it)

**Cons:**
- Initial migration effort to move existing state
- Debugging can be harder (transient logs/state lost)
- Heavier-state hosts (like MTAC with arr stack) need careful planning

## What Needs Persistence in Promiscunix

### Critical System State (`/var/lib/...`)

| Path | Purpose | Host(s) |
|------|---------|---------|
| `/var/lib/sops-nix/` | Age private key for secrets decryption | All with SOPS |
| `/var/lib/tailscale/` | VPN state & machine identity | All |
| `/var/lib/jellyfin/` | Media database & library | MTAC |
| `/var/lib/radarr/` | Movie management DB | MTAC |
| `/var/lib/sonarr/` | TV series DB | MTAC |
| `/var/lib/sabnzbd/` | Config + downloads | MTAC |
| `/var/lib/readarr/` | Ebook DB | MTAC |
| `/var/lib/deluge/` | Torrent state | MTAC |
| `/var/lib/dispatcharr/` | Container data | MTAC, TheTheater |
| `/var/lib/jellyseerr/` | Request database | MTAC |

### Other Critical Paths

| Path | Purpose |
|------|---------|
| `/srv/@data/` | Samba shares (Obsidian, Zotero) |
| `/home/` | User home directories |
| `/etc/machine-id` | Systemd machine identity |
| `/etc/ssh/ssh_host_*` | SSH host keys |
| `/var/log/` | System logs (optional) |

## Recommended Directory Structure

```
/persist/
├── etc/
│   ├── machine-id
│   └── ssh/
├── var/
│   ├── lib/
│   │   ├── sops-nix/key.txt
│   │   ├── tailscale/
│   │   ├── jellyfin/
│   │   └── ...
│   └── log/                     # Optional
├── home/                        # Or use home-manager module
└── srv/                         # Samba data
```

**Key points:**
- `/persist/var/` subdirectory: **Yes, needed**. Most state is in `/var/lib/`
- `/persist/nix/` subdirectory: **Not needed**. The Nix store is declarative and rebuilt from the flake

## Implementation Approach

### Filesystem Backend (Btrfs recommended)

Since Promiscunix already uses Btrfs with Snapper, the cleanest approach:

1. Create a `@persist` subvolume (like existing `@data`)
2. Configure root (`@`) to reset on boot (snapshot rollback or fresh creation)
3. Use impermanence module to bind-mount from `/persist`

### Per-Module Persistence (Recommended Pattern)

Each host has different services, so each needs different `/var/lib/*` paths persisted. Rather than maintaining per-host persistence lists, **each module declares its own persistence needs**.

The impermanence module merges `environment.persistence` across all imports, so:
- When a host imports `(mod "jellyfin")` → gets `/var/lib/jellyfin` persisted
- When a host imports `(mod "arr")` → gets radarr, sonarr, etc. persisted
- Core module handles common paths (ssh keys, machine-id, sops-nix)

```
modules/
├── core/
│   └── impermanence.nix      # Common paths all machines need
└── systemLevel/
    ├── jellyfin/
    │   └── default.nix       # Adds /var/lib/jellyfin
    ├── arr/
    │   └── default.nix       # Adds /var/lib/radarr, sonarr, etc.
    └── guacamole/
        └── default.nix       # Adds its paths
```

### Core Impermanence Module

Handles paths every machine needs:

```nix
# modules/core/impermanence.nix
{ inputs, ... }:
{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;

    directories = [
      "/var/lib/sops-nix"
      "/var/lib/tailscale"
      "/var/log"
    ];

    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };
}
```

### Service Module Examples

Each service module adds its own persistence. These merge with core automatically:

```nix
# modules/systemLevel/jellyfin/default.nix
{ ... }: {
  services.jellyfin.enable = true;

  # Merges with core persistence
  environment.persistence."/persist".directories = [
    "/var/lib/jellyfin"
  ];
}
```

```nix
# modules/systemLevel/arr/default.nix
{ ... }: {
  # ... service config ...

  environment.persistence."/persist".directories = [
    "/var/lib/radarr"
    "/var/lib/sonarr"
    "/var/lib/sabnzbd"
    "/var/lib/readarr"
    "/var/lib/prowlarr"
    "/var/lib/deluge"
  ];
}
```

```nix
# modules/systemLevel/guacamole/default.nix
{ ... }: {
  # ... service config ...

  # Guacamole config is generated at boot from SOPS secrets,
  # so only guacd state needs persistence (if any)
  environment.persistence."/persist".directories = [
    "/var/lib/guacamole"
  ];
}
```

### Result Per Host

| Host | Imports | Persisted Paths |
|------|---------|-----------------|
| **MTAC** | jellyfin, arr, guacamole, xrdp | Core + all service paths |
| **virtnix** | guacamole, xrdp | Core + guacamole paths |
| **optiplex** | samba | Core + samba paths |

Host configs stay clean—just the imports list. Persistence follows automatically.

### Relationship with tmpfiles.rules

The existing `systemd.tmpfiles.rules` in modules (like arr) ensure directory structure exists. Persistence declarations sit alongside:
- **tmpfiles** → creates directories with correct permissions
- **persistence** → ensures directories survive reboots

### Flake Input

```nix
# flake.nix
inputs.impermanence.url = "github:nix-community/impermanence";
```

## Recommended Rollout Order

1. **virtnix** (test VM) - Perfect proving ground, already ephemeral
2. **Workstations** (optiplex, theBullpen, TheTheater) - Less stateful
3. **MTAC** (last) - Most stateful, highest risk

## Resources

- [Impermanence Module](https://github.com/nix-community/impermanence) - Official module and README
- [Erase Your Darlings](https://grahamc.com/blog/erase-your-darlings/) - Original concept blog post
- [Video Tutorial](https://www.youtube.com/watch?v=YPKwkWtK7l0) - Visual walkthrough
