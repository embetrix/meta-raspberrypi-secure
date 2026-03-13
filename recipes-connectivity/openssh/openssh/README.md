# SSH CA Quickstart

Generate CA key pair:

```bash
ssh-keygen -t ed25519 -f ssh_ca_key -C "Embetrix SSH CA"
```

Create client keys:

```bash
ssh-keygen -t ed25519 -f rpi_key  -C "rpi key"
ssh-keygen -t ed25519 -f root_key -C "root key"
```

Sign client keys with the CA:

```bash
ssh-keygen -s ssh_ca_key -I user-rpi  -n rpi  -V +1w rpi_key.pub
ssh-keygen -s ssh_ca_key -I user-root -n root -V +1d root_key.pub
```

Login:

```bash
ssh -i ~/.ssh/rpi_key  rpi@<device-ip>
ssh -i ~/.ssh/root_key root@<device-ip>
```

Note: keep `ssh_ca_key` private. Only `ssh_ca_key.pub` goes to the target (`/etc/ssh/ssh_ca_key.pub`).

Security warning: do not sign or distribute `root` login keys in normal operation. 
If emergency root access is required, issue short-lived root certificates only,
keep them tightly controlled, and revoke them immediately after use.

