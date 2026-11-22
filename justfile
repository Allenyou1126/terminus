set shell := ["bash", "-c"]

default:
    @just --list --list-heading "Terminus commands\n"

# Native local deployment: run on the target host.
switch host:
    sudo nixos-rebuild switch --flake .#{{host}}

# Remote Colmena deployment.
apply host:
    nix run .#colmena -- apply --on {{host}}

# Staged remote deployment: activate but keep the old boot default.
test host:
    nix run .#colmena -- apply --goal test --on {{host}}

# Make the new generation the boot default without activating it.
boot host:
    nix run .#colmena -- apply --goal boot --on {{host}}

apply-tag tag:
    nix run .#colmena -- apply --on @{{tag}}

build host:
    nix run .#colmena -- build --on {{host}}

check:
    nix flake check path:. --no-build

discovery:
    nix run .#terminus-discovery

fmt:
    nix fmt

update:
    nix flake update

deploy-key:
    ssh-keygen -t ed25519 -f ~/.ssh/terminus_deploy -C "terminus deploy" -N ""
    @echo "Add ~/.ssh/terminus_deploy.pub to keys/deploy/"
