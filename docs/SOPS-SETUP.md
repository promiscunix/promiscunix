# SOPS + Age Setup Guide

How SOPS and age work together for secrets management in Promiscunix.

## Conceptual Overview

Think of it like a lockbox system with public/private keypairs:

```
┌─────────────────────────────────────────────────────────────────┐
│                    YOUR REPO (.sops.yaml)                       │
│                                                                 │
│  "These PUBLIC keys can encrypt/decrypt secrets"                │
│                                                                 │
│  keys:                                                          │
│    - &mykey age1rmzkludvq...  ← PUBLIC key (safe to commit)    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                    sops encrypts with this
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              ENCRYPTED SECRET FILE (in git)                     │
│         modules/systemLevel/guacamole/secrets/user-mapping.yaml │
│                                                                 │
│  guacamole_username: ENC[AES256_GCM,data:abc123...]            │
│  guacamole_password: ENC[AES256_GCM,data:xyz789...]            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
               At boot, sops-nix decrypts using...
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│            THE MACHINE (/var/lib/sops-nix/key.txt)              │
│                                                                 │
│  AGE-SECRET-KEY-1QQQQ...   ← PRIVATE key                       │
│                              (never in git, manually placed)    │
│                                                                 │
│  This private key corresponds to the public key in .sops.yaml   │
└─────────────────────────────────────────────────────────────────┘
```

## Key Locations

| File | Location | Purpose |
|------|----------|---------|
| `.sops.yaml` | Repo root | Lists public keys that can decrypt secrets |
| `keys-desktop.txt` | `~/.config/sops/age/` | Your private key (on your workstation) |
| `key.txt` | `/var/lib/sops-nix/` | Machine's private key (on each host) |

## Setting Up a New Machine

### Option A: Use Your Existing Key (Simpler)

Best for personal setups where one key is acceptable for all machines.

```bash
# Copy your existing private key to the new machine
ssh newmachine "sudo mkdir -p /var/lib/sops-nix && sudo chmod 700 /var/lib/sops-nix"
cat ~/.config/sops/age/keys-desktop.txt | \
  ssh newmachine "sudo tee /var/lib/sops-nix/key.txt > /dev/null && sudo chmod 600 /var/lib/sops-nix/key.txt"
```

### Option B: Per-Host Keys (More Secure)

Each machine has its own keypair. Compromise of one host doesn't expose others.

```bash
# 1. Generate new keypair for the host
age-keygen -o /tmp/host-key.txt
# Output shows: public key: age1xxxxx...

# 2. Add the public key to .sops.yaml
#    keys:
#      - &mykey age1rmzkludvq...
#      - &newhost age1xxxxx...     <- add this
#    creation_rules:
#      - path_regex: ...
#        key_groups:
#          - age:
#              - *mykey
#              - *newhost           <- add to rules

# 3. Re-encrypt all secrets with the new key
sops updatekeys modules/systemLevel/guacamole/secrets/user-mapping.yaml

# 4. Deploy the private key to the host
cat /tmp/host-key.txt | \
  ssh newhost "sudo tee /var/lib/sops-nix/key.txt > /dev/null && sudo chmod 600 /var/lib/sops-nix/key.txt"

# 5. Clean up local copy
rm /tmp/host-key.txt
```

## Setting Up virtnix (Test VM)

The VM is ephemeral—starts fresh each boot. Use your existing desktop key.

### Step 1: Build and Start the VM

```bash
nixos-rebuild build-vm --flake .#virtnix
./result/bin/run-virtnix-vm
```

### Step 2: Copy Age Key into VM (from another terminal)

```bash
# Wait for VM to boot, then copy the key
ssh -p 2222 vmtest@localhost "sudo mkdir -p /var/lib/sops-nix && sudo chmod 700 /var/lib/sops-nix"
cat ~/.config/sops/age/keys-desktop.txt | \
  ssh -p 2222 vmtest@localhost "sudo tee /var/lib/sops-nix/key.txt > /dev/null && sudo chmod 600 /var/lib/sops-nix/key.txt"
```

### Step 3: Trigger Secret Decryption

```bash
ssh -p 2222 vmtest@localhost "sudo /run/current-system/activate && sudo systemctl restart guacamole-server tomcat"
```

### Step 4: Access Guacamole

Open `http://localhost:8081/guacamole/` in your browser.

### One-Liner for Future VM Runs

After the VM boots:

```bash
ssh -p 2222 vmtest@localhost "sudo mkdir -p /var/lib/sops-nix && sudo chmod 700 /var/lib/sops-nix" && \
cat ~/.config/sops/age/keys-desktop.txt | ssh -p 2222 vmtest@localhost "sudo tee /var/lib/sops-nix/key.txt > /dev/null && sudo chmod 600 /var/lib/sops-nix/key.txt" && \
ssh -p 2222 vmtest@localhost "sudo /run/current-system/activate && sudo systemctl restart guacamole-server tomcat"
```

## Editing Encrypted Secrets

```bash
cd /path/to/nixfiles
nix-shell -p sops --run "SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys-desktop.txt sops <path-to-secret.yaml>"
```

This opens the decrypted file in your editor. Save and exit to re-encrypt.

## Quick Reference

| Task | Command |
|------|---------|
| View your public key | `grep "public key" ~/.config/sops/age/keys-desktop.txt` |
| Generate new keypair | `age-keygen -o keyfile.txt` |
| Edit encrypted secret | `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys-desktop.txt sops <file>` |
| Re-encrypt with new key | `sops updatekeys <file>` |
| Check key on machine | `sudo cat /var/lib/sops-nix/key.txt` |

## Troubleshooting

### "Failed to decrypt"

The machine's private key doesn't match any public key in `.sops.yaml`.

1. Check the machine has a key: `sudo cat /var/lib/sops-nix/key.txt`
2. Get its public key from the comment line: `# public key: age1...`
3. Ensure that public key is listed in `.sops.yaml`
4. Re-encrypt secrets: `sops updatekeys <file>`

### Secrets Not Available at Boot

The sops-nix module runs during activation. If services start before activation completes:

```bash
# Re-run activation
sudo /run/current-system/activate

# Restart affected services
sudo systemctl restart <service>
```

### VM Forgets Key After Reboot

Expected behavior—virtnix is ephemeral. Run the key setup one-liner after each VM boot.
