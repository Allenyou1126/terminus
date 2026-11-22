# Deploy keys

Add the public key of a dedicated deployment key as `keys/deploy/*.pub`.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/terminus_deploy -C "terminus deploy" -N ""
cat ~/.ssh/terminus_deploy.pub
# copy it to keys/deploy/<name>.pub
```

The private key stays on the machine used to run `nix run .#colmena -- ...`.
The `deploy` user gets `NOPASSWD: ALL` sudo, so this key is equivalent to
root on deployable hosts. Rotate it like a root credential.
