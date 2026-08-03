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
    * [Serving Plex over HTTPS (`configure_ssl`)](#serving-plex-over-https-configure_ssl)
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
via Cloudflare DNS-01 validation. A separate opt-in, `configure_ssl`, closes
the loop by converting that certificate into a PKCS#12 bundle and wiring it
into Plex's own `Preferences.xml` so Plex serves it directly over HTTPS.

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
`domain_contact_email`. `cert_dir`, `letsencrypt_conf_dir`, `domain_name`,
`dns_provider_email`, and `domain_contact_email` all ship with module
defaults in `data/common.yaml`; `dns_provider` and `dns_provider_token` do
not, and must be supplied via your own Hiera data (automatic parameter
lookup on `plexmediaserver::secure`):

```yaml
plexmediaserver::secure::dns_provider: 'cloudflare'
plexmediaserver::secure::dns_provider_token: '%{alias('profile::plex::cf_token')}'
```

`dns_provider_token` is looked up as `Sensitive[String]` (the module's
`lookup_options` convert it automatically), so store the raw token value in
encrypted Hiera (eyaml, a vault lookup, etc.) — Puppet wraps it once it's
read.

Note the DNS plugin itself is currently **Cloudflare-specific**: the module
always declares `letsencrypt::plugin::dns_cloudflare`, so although the
`dns_provider` parameter reads as generic, only Cloudflare DNS-01 validation
is actually wired up in this release.

### Serving Plex over HTTPS (`configure_ssl`)

Setting `configure_ssl => true` completes the loop started by
`use_letsencrypt`: it takes the certificate `plexmediaserver::secure`
obtains and makes Plex serve it directly, instead of just keeping it
current on disk. `configure_ssl` requires `use_letsencrypt => true` and a
`ssl_pkcs12_password` — the module `fail()`s compilation with a clear
message if either is missing:

```puppet
class { 'plexmediaserver':
  use_letsencrypt     => true,
  configure_ssl       => true,
  ssl_pkcs12_password => Sensitive('correct-horse-battery-staple'),
}
```

```yaml
# required Hiera data for use_letsencrypt (see above) — configure_ssl needs
# nothing beyond what use_letsencrypt already requires
plexmediaserver::secure::dns_provider: 'cloudflare'
plexmediaserver::secure::dns_provider_token: '%{alias('profile::plex::cf_token')}'
```

Under the hood, `configure_ssl => true` includes `plexmediaserver::ssl`,
which:

* installs a managed deploy script,
  `/usr/local/bin/plexmediaserver-deploy-cert.sh`, that converts the
  Let's Encrypt `fullchain.pem`/`privkey.pem` into a PKCS#12 bundle at
  `<cert_dir>/plexmediaserver.p12` (owned by `plex_user`, mode `0600`),
  writes the p12 password into Plex's `customCertificateKey` preference,
  and restarts Plex using the correct command for the active service
  manager (`systemctl` or `supervisorctl`);
* runs that script automatically whenever the certificate is renewed — it
  is wired in as the `letsencrypt::certonly` cron's success command, so
  renewals rebuild the p12 and restart Plex without any extra steps; and
* uses `augeas` to set `customCertificatePath`, `customCertificateDomain`,
  and `secureConnections` in `Preferences.xml`. `secure_connections`
  defaults to `1` (preferred — Plex will use HTTPS when available but still
  accept plain HTTP); set it to `2` to require HTTPS or `0` to disable it.

The `ssl_pkcs12_password` you pass in never enters the Puppet catalog as a
readable secret end-to-end: it's written to a root-only, mode `0600` file
on the node (`show_diff => false`), and the deploy script reads it from
that file — never from a command line or environment variable — both when
building the p12 and when writing `customCertificateKey`.

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

* **`use_letsencrypt => true` still requires two Hiera keys.**
  `data/common.yaml` ships module defaults for `cert_dir`,
  `letsencrypt_conf_dir`, `domain_name`, `dns_provider_email`, and
  `domain_contact_email`, but `dns_provider` and `dns_provider_token` have
  no defaults and must be supplied via your own Hiera data — see
  [Let's Encrypt](#lets-encrypt-use_letsencrypt) above for the exact keys.
  Note that `use_letsencrypt => true` already `include`s
  `plexmediaserver::secure` internally, so you cannot also declare
  `class { 'plexmediaserver::secure': ... }` yourself — Puppet would raise a
  "Duplicate declaration" error.

* **The DNS provider is currently Cloudflare-specific.** Although the
  `dns_provider` parameter reads as generic (it's passed straight through
  as the `letsencrypt::certonly` `plugin`), `plexmediaserver::secure` always
  declares `class { 'letsencrypt::plugin::dns_cloudflare': }` to install and
  configure the DNS plugin itself. Other DNS-01 providers are not currently
  supported without modifying the module.

* **`configure_ssl` needs Plex claimed first.** Plex only creates
  `Preferences.xml` after it has run for the first time and been claimed
  through its web UI. Until that file exists, the `augeas` resource that
  wires in `customCertificatePath`, `customCertificateDomain`, and
  `secureConnections` safely no-ops — it will not create or clobber the
  file — and a later Puppet run completes the wiring once
  `Preferences.xml` exists. The PKCS#12 bundle itself is generated
  regardless of claim state, since it only depends on the Let's Encrypt
  certificate.

* **No extra system package needed for augeas.** The `augeas` resource
  type and provider ship as part of the AIO `puppet-agent` package itself,
  so no additional module dependency or system package is required to use
  `configure_ssl`.

## Development

Bug reports and pull requests are welcome. Run `pdk validate -a` and
`pdk test unit` before submitting changes.
