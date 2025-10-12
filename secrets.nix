# secrets/secrets.nix
let
  # Your desktop admin key (for encrypting/editing secrets)
  admin = "age1rh06ee5j0cxsk4txz4j28tshpudyvcl5qd9g2mv4xwra4q99zqfsuz39xr";

  # Host keys (so they can decrypt their own secrets at boot)
  optiplex = "age1y6dnet9xsjn9zcepm3dhup23nt9mnl5tjjnwzsp4kjps3waz4qgs43w42q"; # This is the one you got from optiplex!

  allAdmins = [admin];
  allHosts = [optiplex];
in {
  # Admin-controlled user identity/roles
  "secrets/users/damajha/userInfo.toml.age".publicKeys = allAdmins ++ allHosts;
  "secrets/hosts/optiplex/systemInfo.toml.age".publicKeys = allAdmins ++ allHosts;
}
