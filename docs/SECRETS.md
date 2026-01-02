# Secrets Management with SOPS

This repo uses [SOPS](https://github.com/getsops/sops) with [age](https://github.com/FiloSottile/age) encryption to manage sensitive data like passwords, API keys, and tokens.

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  Your Desktop                                               │
│  ~/.config/sops/age/keys-desktop.txt                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ AGE-SECRET-KEY-1XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX        │  │ ← Private key (NEVER in git)
│  │ # public key: age1abc123...                           │  │ ← Public key (safe to share)
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                    encrypts/decrypts
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Git Repository (safe to push)                              │
│  modules/systemLevel/guacamole/secrets/user-mapping.yaml    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ password: ENC[AES256_GCM,data:xyz123...,tag:abc...]   │  │ ← Encrypted (useless without key)
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                    decrypted at boot by
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Target Host (e.g., MTAC)                                   │
│  /var/lib/sops-nix/key.txt                                  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ AGE-SECRET-KEY-1XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX        │  │ ← Copy of private key
│  └───────────────────────────────────────────────────────┘  │
│                              │                              │
│                              ▼                              │
│  /run/secrets/password → "actual_password"                  │ ← Decrypted (tmpfs, never on disk)
└─────────────────────────────────────────────────────────────┘
```

## Key Files

| File | Location | Purpose | In Git? |
|------|----------|---------|---------|
| `keys-desktop.txt` | `~/.config/sops/age/` | Your private key for encrypting/editing | **NO** |
| `key.txt` | `/var/lib/sops-nix/` (on hosts) | Host's key for decrypting at boot | **NO** |
| `.sops.yaml` | Repo root | Defines which keys can decrypt which files | Yes |
| `*.yaml` | `*/secrets/` dirs | Encrypted secrets | Yes |

## Common Tasks

### Edit existing secrets

```bash
cd /path/to/nixfiles
nix-shell -p sops --run "SOPS_AGE_KEY_FILE=\$HOME/.config/sops/age/keys-desktop.txt sops <path-to-secret.yaml>"
```

Your editor opens with decrypted content. Save and exit to re-encrypt.

### View secrets without editing

```bash
nix-shell -p sops --run "SOPS_AGE_KEY_FILE=\$HOME/.config/sops/age/keys-desktop.txt sops -d <path-to-secret.yaml>"
```

### Create new secrets file

1. Create the yaml with plaintext values:
   ```yaml
   api_key: my-secret-key
   password: hunter2
   ```

2. Add path pattern to `.sops.yaml` if needed:
   ```yaml
   creation_rules:
     - path_regex: my/new/secrets/.*\.yaml$
       key_groups:
         - age:
             - *mykey
   ```

3. Encrypt:
   ```bash
   nix-shell -p sops --run "SOPS_AGE_KEY_FILE=\$HOME/.config/sops/age/keys-desktop.txt sops -e -i my/new/secrets/file.yaml"
   ```

### Add a new host

1. Get the host's public key (from SSH host key):
   ```bash
   nix-shell -p ssh-to-age --run "ssh user@host 'sudo cat /etc/ssh/ssh_host_ed25519_key.pub' | ssh-to-age"
   ```

2. Add to `.sops.yaml`:
   ```yaml
   keys:
     - &mykey age1existing...
     - &newhost age1newkey...   # Add this
   creation_rules:
     - path_regex: modules/.*/secrets/.*\.yaml$
       key_groups:
         - age:
             - *mykey
             - *newhost          # Add this
   ```

3. Re-encrypt all secrets for the new host:
   ```bash
   nix-shell -p sops --run "SOPS_AGE_KEY_FILE=\$HOME/.config/sops/age/keys-desktop.txt sops updatekeys modules/systemLevel/guacamole/secrets/user-mapping.yaml"
   ```

4. Copy the age key to the new host:
   ```bash
   ssh user@host "sudo mkdir -p /var/lib/sops-nix && sudo tee /var/lib/sops-nix/key.txt > /dev/null && sudo chmod 600 /var/lib/sops-nix/key.txt" < ~/.config/sops/age/keys-desktop.txt
   ```

### Move to a new workstation

Copy your private key to the new machine:
```bash
# On old machine - save this somewhere safe (password manager, etc.)
cat ~/.config/sops/age/keys-desktop.txt

# On new machine
mkdir -p ~/.config/sops/age
# Paste the key content into:
nano ~/.config/sops/age/keys-desktop.txt
chmod 600 ~/.config/sops/age/keys-desktop.txt
```

## Security Notes

### What SOPS protects against
- Secrets exposed in git history
- Secrets visible to anyone cloning your repo
- Secrets in laptop backups/cloud sync
- Accidental exposure in logs/issues

### What SOPS does NOT protect against
- Root access on target hosts (they need the key to decrypt)
- Someone with your private key file
- Secrets in memory on running systems

### Best practices
- Never commit unencrypted secrets
- Back up your private key securely (password manager)
- Use separate keys per host if high security needed
- Rotate secrets if a key is compromised

## Current Secrets

| Path | Contents |
|------|----------|
| `modules/systemLevel/guacamole/secrets/user-mapping.yaml` | Guacamole + RDP credentials |

## Troubleshooting

**"config file not found"**
- Run sops from the repo root where `.sops.yaml` lives

**"no identity matched any of the recipients"**
- Your key isn't in `.sops.yaml` for this file
- Wrong `SOPS_AGE_KEY_FILE` path

**"Failed to get the data key"**
- The key file doesn't exist or has wrong permissions
- Use `$HOME` not `~` in environment variables

**Secrets not decrypted on host**
- Check `/var/lib/sops-nix/key.txt` exists and is readable by root
- Verify the host's key is in `.sops.yaml` and secrets were re-encrypted
