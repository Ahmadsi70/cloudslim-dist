# CloudSlim — Agent Distribution

This repository hosts the **installer and release binaries** for the
CloudSlim agent. The source code lives in the private main repository.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Ahmadsi70/cloudslim-dist/main/install.sh | bash
```

The installer asks for your license key (get one at the CloudSlim dashboard).

## What gets installed

- `/usr/local/bin/cloudslim-agent` — the 3 MB Rust agent
- `/etc/cloudslim/agent.env` — your license configuration
- a hardened systemd service (`cloudslim-agent`), enabled and started

Supported: Linux x86_64 & ARM64 — Ubuntu 20.04+, Debian 11+, RHEL 8+, Amazon Linux 2.

## Verifying downloads

Every release ships a `SHA256SUMS` file. Verify before installing:

```bash
sha256sum -c SHA256SUMS
```

© HERA Tech — proprietary software. Redistribution of the binaries outside
this release channel is not permitted.
