# Promiscunix

A role-based NixOS configuration system that automatically discovers and deploys users across multiple hosts based on their roles, powered by simple TOML files.

## 🧪 Try It Out

This repository includes **virtnix**, a pre-configured virtual machine you can spin up to experiment with adding users and roles without affecting your main system.

**Build It:**
`nixos-rebuild build-vm --flake .#virtnix`

Run the command given after build is complete

**Quick start:**
```bash
# Initial login credentials
Username: vmtest
Password: vmtest
```

Play around with creating new users, adding roles, and seeing how the system automatically manages user deployment!

## 🎯 What This Accomplishes

This configuration system solves a common problem: **managing multiple users across multiple machines without duplicating configuration.**

Instead of manually configuring each user on each host, you:
1. Define each user once in a `userInfo.toml` file with their roles
2. Define each host once in a `systemInfo.toml` file with required roles
3. The system automatically installs users on hosts where their roles match

## 🏗️ Architecture Overview

### Core Concept: Role-Based User Deployment

```
User: damajha                    Host: optiplex
├── roles: ["workstation"]  ───► ├── includeRoles: ["workstation"]
└── shell: fish                  └── mainUser: damajha
                                      
Result: damajha is automatically installed on optiplex
```

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│ 1. User Discovery (flake.nix)                              │
│    Scans users/ directory for all userInfo.toml files      │
│    Creates single userInfos database: { damajha = {...} }  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Host Factory (flake.nix)                                │
│    Reads each host's systemInfo.toml                       │
│    Passes userInfos database to all modules                │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Role Matching (modules/systemLevel/accounts)            │
│    Filters userInfos by host's includeRoles                │
│    Creates system accounts for matched users               │
│    Generates Home Manager configs for each user            │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Directory Structure

```
promiscunix/
├── flake.nix                      # Entry point: discovers users & creates hosts
├── hosts/
│   ├── optiplex/
│   │   ├── systemInfo.toml       # Host config: roles, network, mainUser
│   │   ├── configuration.nix     # NixOS configuration
│   │   └── hardware-configuration.nix
│   └── virtnix/
│       ├── systemInfo.toml
│       └── ...
├── users/
│   └── damajha/
│       ├── userInfo.toml         # User identity: roles, name, email, shell
│       └── home.nix              # Home Manager configuration
└── modules/
    ├── core/
    │   └── default.nix           # Base system config
    ├── systemLevel/
    │   ├── accounts/             # Role-based user installation logic
    │   └── ...
    └── userLevel/
        ├── helix/                # User program configs
        ├── fish/
        └── ...
```

## 🔧 Configuration Files

### `userInfo.toml` - User Definition

Each user has a single source of truth:

```toml
# users/damajha/userInfo.toml
fullName = "Dale Appleby"
email    = "dale@gmail.com"
userName = "damajha"
shell    = "fish"
editor   = "helix"
roles    = ["workstation", "admin"]
```

**Roles** determine which hosts this user appears on.

### `systemInfo.toml` - Host Definition

Each host declares what it needs:

```toml
# hosts/optiplex/systemInfo.toml
hostName = "optiplex"
ipAddr = "192.168.1.201/24"
networkInterfaceName = "enp2s0"
mainUser = "damajha"

[accounts]
includeRoles = ["workstation"]  # Install users with these roles
extraUsers   = []                # Force-include specific users
exclude      = []                # Force-exclude specific users
wheelRole    = "admin"           # Role that gets sudo access
```

## 🎨 Key Features

### 1. **Single Source of Truth**
Each user is defined once. Changes to a user's shell, name, or email automatically propagate to all hosts they're on.

### 2. **Role-Based Deployment**
```toml
# User has roles: ["workstation", "admin"]
# Host wants roles: ["workstation"]
# Result: User is installed ✓
```

### 3. **Automatic Shell Management**
The system only enables shells that selected users actually need:
```nix
# If damajha uses fish and alice uses zsh:
programs.fish.enable = true;  # Enabled
programs.zsh.enable = true;   # Enabled
programs.bash.enable = false; # Not needed, not enabled
```

### 4. **Dynamic Permission Management**
Users get wheel access (sudo) if they:
- Are the `mainUser`, OR
- Have `admin = true` in their userInfo, OR
- Have a role matching the host's `wheelRole`

### 5. **Flexible Role Matching**
```toml
includeRoles = ["workstation"]     # Specific roles
includeRoles = ["*"]               # All users
extraUsers = ["alice"]             # Always include alice
exclude = ["bob"]                  # Never include bob
```

## 🚀 Usage

### Adding a New User

1. Create user directory:
```bash
mkdir -p users/alice
```

2. Create `users/alice/userInfo.toml`:
```toml
fullName = "Alice Smith"
email    = "alice@example.com"
userName = "alice"
shell    = "zsh"
editor   = "vim"
roles    = ["server", "developer"]
```

3. Create `users/alice/home.nix`:
```nix
{ pkgs, userInfo, ... }: {
  imports = [ ../../modules/userLevel/vim ];
  home.packages = [ pkgs.git ];
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
}
```

Alice will now automatically appear on any host with `includeRoles = ["server"]` or `includeRoles = ["developer"]`.

### Adding a New Host

1. Create host directory:
```bash
mkdir -p hosts/laptop
```

2. Create `hosts/laptop/systemInfo.toml`:
```toml
hostName = "laptop"
ipAddr = "192.168.1.100/24"
networkInterfaceName = "wlan0"
mainUser = "damajha"

[accounts]
includeRoles = ["workstation"]
```

3. Add to `flake.nix`:
```nix
nixosConfigurations = {
  optiplex = mkHost "optiplex";
  virtnix = mkHost "virtnix";
  laptop = mkHost "laptop";      # Add this line
};
```

4. Generate hardware config on the laptop:
```bash
nixos-generate-config --show-hardware-config > hosts/laptop/hardware-configuration.nix
```

5. Build it:
```bash
sudo nixos-rebuild switch --flake .#laptop
```

### Deploying

```bash
# Build and activate on remote host
nixos-rebuild switch \
  --flake .#optiplex \
  --target-host damajha@192.168.1.201 \
  --build-host damajha@192.168.1.201 \
  --use-remote-sudo
```

## 🎓 Design Principles

1. **Declarative**: User presence is determined by roles, not manual configuration
2. **DRY (Don't Repeat Yourself)**: Each user defined once, deployed everywhere needed
3. **Composable**: Mix and match roles to create different user sets per host
4. **Type-Safe**: TOML files provide structure; Nix ensures correctness
5. **Auditable**: Git tracks who has access to which hosts via role changes

## 📚 How Role Matching Works

The `modules/systemLevel/accounts/default.nix` module implements the matching logic:

```nix
# For each user in userInfos:
hasAnyIncludedRole = u: 
  let rs = userInfos.${u}.roles or [];
  in (includeRoles == ["*"]) || 
     lib.any (r: lib.elem r includeRoles) rs;

# Build final user list:
byRoles = filter hasAnyIncludedRole allUsers;
base = unique (byRoles ++ extraUsers ++ [mainUser]);
names = subtractLists exclude base;
```

This creates a list of users to install, then:
1. Creates system accounts for each
2. Configures their shells and groups
3. Generates Home Manager configurations
4. Imports each user's `home.nix`

## 🔮 Future Enhancements

- [ ] Encrypted `userInfo.toml` files for sensitive data
- [ ] User preference files (`userPrefs.toml`) separate from identity
- [ ] Role-based package installation
- [ ] Per-host user overrides

## 🤝 Contributing

This is a personal configuration, but feel free to use it as inspiration for your own setup!

## 📄 License

MIT

---

**Why "Promiscunix"?** Because I like to play fast and loose with Linux, Opensource and Nix! 😄
