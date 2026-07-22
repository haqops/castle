# castle

**Agent Castle** — NixOS foundation for self-hosted infrastructure where
humans and their agents work together.

Castle is a library of NixOS modules and tooling: declarative,
opinionated, encrypted end to end. Point it at some Linux boxes — a
Hetzner VM, a machine under your desk, a datacenter in your basement —
and out comes a working environment for the mixed human/agent workflow.

## Why

The substrate for humans working alongside agents doesn't really exist
yet. Team chat wasn't designed for it, cloud IDEs assume one human per
seat, docker-on-laptop is not a place for agents to actually live.
Teams end up gluing SaaS accounts together, scattering conversation
history across random tools, and hoping nobody's laptop dies with a
session inside it.

Castle takes the position that this substrate should be:

- **Yours.** Self-hosted, encrypted disks, no third party sitting in
  the middle of your agent conversations.
- **Nix-first.** Every host, user, service, and secret declared in one
  repo. Rebuilds are reproducible. Rollback is a git revert.
- **Small.** Not fleet management. A handful of nodes, arranged
  however fits.
- **Opinionated.** Sensible defaults, one blessed way to do each
  thing. Cloudflare Origin CA over ACME. sops-nix over Vault. ZFS over
  tin foil.

## What you get

A library of NixOS modules for the pieces you need:

- **Long-form discussion** — Discourse behind Caddy, private by default
  (no guest reads, invite-only signup, admin-approved accounts).
- **Code hosting** — Forgejo with declaratively provisioned accounts.
- **A user registry** — `castle.users.<name>` declares people once;
  every service reads the same list.
- **Encrypted disks** — ZFS with per-host passphrase, entered remotely
  over SSH into the initrd.
- **One-shot provisioning** — `install-host <name>` generates keys,
  plants secrets, and kexecs a NixOS installer over any live Linux.
- **Declarative deploys** — `deploy .#<name>` with automatic rollback.

Arrange the pieces however you want. Everything on one node. One node
per service. A dedicated node for each person's agents. Castle is a
toolkit; the topology is yours.

More services (issue tracking, chat, dashboards, agent-facing APIs) land
as they're needed.

## Design tenets

- **Data-only host declarations.** Each host is one entry in
  `hosts.nix`, tuned through `castle.*` options. Nothing per-host is
  hardcoded in the library.
- **One source of truth for users.** `castle.users.<name>` propagates
  to every service that has accounts.
- **Encrypted by default.** No unencrypted disks in the fleet.
- **No ACME.** Cloudflare Origin CA, fifteen-year cert, one rotation
  on your calendar instead of one per certificate.
- **No forking.** Consume as a flake input, tune via options, add your
  own modules alongside.

## Getting started

```sh
mkdir my-castle && cd my-castle
nix flake init -t github:haqops/castle
```

Everything about operating your castle — Cloudflare setup, sops
recipients, adding a host, deploying — lives in the README that gets
copied into your instance.

## Reference

Technical reference for the library — flake outputs, module options,
repo layout — lives in [`docs/reference.md`](docs/reference.md).
