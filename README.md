# plexmediaserver

## Table of Contents

1. [Description](#description)
1. [Setup](#setup)
    * [Requirements](#requirements)
1. [Usage](#usage)
    * [Basic VM usage (systemd)](#basic-vm-usage-systemd)
    * [LXC usage (supervisord)](#lxc-usage-supervisord)
    * [Forcing the service manager](#forcing-the-service-manager)
    * [Let's Encrypt (`use_letsencrypt`)](#lets-encrypt-use_letsencrypt)
1. [Reference](#reference)
1. [Limitations](#limitations)
1. [Development](#development)

## Description

This module installs and manages [Plex Media Server](https://www.plex.tv/) from
the official Plex repository:

* On RedHat-family systems (CentOS, RHEL, Rocky, AlmaLinux, OracleLinux) it manages
  the repo with a native `yumrepo` resource.
* On Debian-family systems (Debian, Ubuntu) it manages the repo with `apt::source`,
  importing the Plex signing key as a dearmored keyring.

The module also manages how the `plexmediaserver` process is supervised, since
that differs depending on whether the target is a full VM (with systemd as
PID 1) or a Proxmox-style unprivileged LXC container (which typically runs
`supervisord` as PID 1 and has no systemd).

Optionally, the module can front Plex with a Let's Encrypt certificate issued
via Cloudflare DNS-01 validation.

## Setup

### Requirements

This module declares the following dependencies in `metadata.json`:

* [`puppetlabs/stdlib`](https://forge.puppet.com/modules/puppetlabs/stdlib) (`>= 9.0.0 < 11.0.0`)
* [`puppetlabs/apt`](https://forge.puppet.com/modules/puppetlabs/apt) (`>= 9.0.0 < 11.0.0`) — used for the Debian/Ubuntu repo
* [`puppetlabs/yumrepo_core`](https://forge.puppet.com/modules/puppetlabs/yumrepo_core) (`>= 1.0.0 < 4.0.0`) — used for the RedHat-family repo
* [`puppet/letsencrypt`](https://forge.puppet.com/modules/puppet/letsencrypt) (`>= 10.0.0 < 12.0.0`) — only required when `use_letsencrypt => true`

Note: this module does **not** depend on `puppet/yum`; the RedHat repository is
managed directly with the native `yumrepo` type via `puppetlabs/yumrepo_core`.

Supported operating systems (see `metadata.json` for exact releases): CentOS,
RHEL, Rocky, AlmaLinux, OracleLinux, Debian, and Ubuntu.

## Usage

### Basic VM usage (systemd)

On a regular VM (or any host where the `virtual` fact is not `lxc`), the
service manager auto-detects to `systemd` and the module manages the vendor
`plexmediaserver` systemd service:

```puppet
include plexmediaserver
```

This installs the package, configures the repository, and ensures the
`plexmediaserver` service is running and enabled via `service { 'plexmediaserver': }`.

### LXC usage (supervisord)

Inside an LXC container where `virtual` reports `lxc` (e.g. an unprivileged
Proxmox LXC with no systemd), the module auto-detects and switches to managing
Plex via `supervisord` instead of a systemd service:

```puppet
include plexmediaserver
```

No changes are needed to your Puppet code — the auto-detection is driven by
the `virtual` fact. Under the hood this:

* installs the `supervisor` package (name/paths come from OS-family Hiera data),
* writes a supervisor program config from an EPP template
  (`/etc/supervisor/conf.d/plexmediaserver.conf` on Debian-family hosts,
  `/etc/supervisord.d/plexmediaserver.ini` on RedHat-family hosts) with
  `autostart`, `autorestart`, `stopasgroup`, and `killasgroup` set, plus the
  Plex environment variables (`LD_LIBRARY_PATH`,
  `PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR`), and
* runs `supervisorctl update` (refreshonly, triggered by changes to the
  program config) to load it — it does **not** manage a `service` resource.

### Forcing the service manager

The auto-detected choice can be overridden with the `service_manager`
parameter (`Enum['systemd', 'supervisord']`):

```puppet
class { 'plexmediaserver':
  service_manager => 'supervisord',
}
```

This is useful, for example, on an LXC that *does* run systemd but where you
still want supervisord to own the Plex process — see
[Limitations](#limitations) below for what you need to do yourself in that case.

### Let's Encrypt (`use_letsencrypt`)

Setting `use_letsencrypt => true` includes `plexmediaserver::secure`, which
uses `puppet/letsencrypt` with the Cloudflare DNS-01 plugin to obtain and
renew a certificate for Plex, and installs a cron job that stops Plex before
renewal and starts it again afterwards using the correct command for the
active service manager (`systemctl` or `supervisorctl`).

```puppet
class { 'plexmediaserver':
  use_letsencrypt => true,
}
```

`plexmediaserver::secure` itself takes parameters such as `dns_provider`,
`dns_provider_token`, `domain_name`, `dns_provider_email`, and
`domain_contact_email` — see [Limitations](#limitations) for a known issue
with how these are currently supplied via Hiera.

## Reference

See the inline Puppet Strings documentation in `manifests/init.pp` for the
full list of `plexmediaserver` class parameters and their defaults (repo URIs,
`install_version`, `ensure`, `service_manager`, the supervisord tunables
`plex_user`/`plex_binary`/`plex_support_dir`, and the OS-family
supervisor defaults `supervisor_package`/`supervisor_conf_dir`/`supervisor_conf_ext`).

## Limitations

* **systemd LXCs that still want supervisord.** The module does not detect or
  mask the vendor `plexmediaserver` systemd unit. If you are on an LXC that
  does run systemd but you want Plex managed by supervisord anyway, set
  `service_manager => 'supervisord'` explicitly — the module will not disable
  the systemd unit for you, so you must mask/disable it yourself to avoid two
  supervisors fighting over the same process.

* **Known issue: `use_letsencrypt => true` requires explicit Hiera data.**
  The shipped `data/common.yaml` defines
  `plexmediaserver::secure::domain_email`, but `plexmediaserver::secure`
  actually declares `dns_provider_email` and `domain_contact_email` — the
  Hiera key does not match either parameter name, so it is never picked up.
  Relying on the module's default Hiera data alone will therefore fail to
  compile (`dns_provider`, `dns_provider_token`, and `domain_name` also have
  no defaults and must be supplied).

  Note that `use_letsencrypt => true` already `include`s
  `plexmediaserver::secure` internally, so you cannot also declare
  `class { 'plexmediaserver::secure': ... }` yourself — Puppet would raise a
  "Duplicate declaration" error. The only working fix is to supply the
  required values via Hiera, using the class's real parameter names as the
  keys (automatic parameter lookup):

  ```yaml
  # e.g. in your own site data, keyed above/instead of this module's data/common.yaml
  plexmediaserver::secure::dns_provider: 'cloudflare'
  plexmediaserver::secure::dns_provider_token: '%{alias('profile::plex::cf_token')}'
  plexmediaserver::secure::domain_name: 'plex.example.com'
  plexmediaserver::secure::cert_dir: '/var/lib/plexmediaserver/Resources/SSL'
  plexmediaserver::secure::letsencrypt_conf_dir: '/etc/letsencrypt'
  plexmediaserver::secure::dns_provider_email: 'you@example.com'
  plexmediaserver::secure::domain_contact_email: 'you@example.com'
  ```

  Until the mis-keyed `data/common.yaml` entry is fixed upstream, these keys
  must be set in Hiera data that takes precedence over this module's own
  `data/common.yaml` (e.g. in your control-repo's site hierarchy).

## Development

Bug reports and pull requests are welcome. Run `pdk validate -a` and
`pdk test unit` before submitting changes.
