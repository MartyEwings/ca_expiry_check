# ca_expiry_check

#### Table of Contents

1. [Description](#description)
2. [Compatibility](#compatibility)
3. [Use cases](#use-cases)
4. [Setup](#setup)
5. [Usage](#usage)
6. [Reference](#reference)
7. [Upgrading from 2.x](#upgrading-from-2x)
8. [Limitations](#limitations)
9. [Development](#development)

## Description

The Puppet CA certificate sits at the root of trust for your entire Puppet estate. When it expires,
agents can no longer authenticate to the primary server and the whole deployment grinds to a halt -
and because the CA is typically valid for years, its expiry is easy to forget until it is too late.

This module surfaces that expiry **before** it bites. It ships a structured fact describing the CA
certificate's expiry, plus an optional class that turns that fact into an actionable alert: a Puppet
report notification, a log warning, a hard catalog failure, and/or a metrics file for your monitoring
stack.

It works on both **Puppet (core) open source** and **Puppet Enterprise**, on the host running the
Puppet CA (the primary server, or a dedicated CA server / compiler hosting the CA). It is
**dependency-free** - no `stdlib`, nothing to pull in - so it is safe to drop onto a primary server.

## Compatibility

| Component | Supported |
| --------- | --------- |
| Puppet (core) | 8.x, 9.x (when released) |
| Puppet Enterprise | 2025.x and later |
| Facter | 4.x (bundled with Puppet 8) |
| Ruby | 3.2+ (vendored with Puppet 8) |

Supported operating systems are listed in [`metadata.json`](metadata.json) (RHEL/AlmaLinux/Rocky/
Oracle 8-10, CentOS 9, Debian 11-12, Ubuntu 20.04-24.04, SLES 15). The module only does meaningful
work on the CA host; classifying it elsewhere is a harmless no-op.

> The module auto-detects the CA certificate at `/etc/puppetlabs/puppetserver/ca/ca_crt.pem`
> (Puppet 8 and PE) and falls back to the legacy `/etc/puppetlabs/puppet/ssl/ca/ca_crt.pem`.

## Use cases

* **Fact-driven dashboards / PuppetDB queries.** The `puppet_ca_expiry` fact is reported to
  PuppetDB. Query for CA certificates expiring soon across every primary/compiler without logging
  in to any of them - for example in the PE console, with `puppet query`, or in a custom report.
* **Prometheus / Grafana alerting.** Enable `manage_textfile` to write a node_exporter textfile so
  Prometheus scrapes `puppet_ca_expiry_seconds` / `puppet_ca_expired` and you can alert/graph on it.
* **Splunk / log pipeline ingest.** Enable `manage_report` to drop a small JSON status file that a
  forwarder or log shipper can ingest.
* **Alert on every Puppet run.** Classify the CA host and get a `notify` in each report once the
  certificate is inside the warning window - visible in the PE console as an event.
* **Hard gate.** Set `critical_severity => 'fail'` to make the catalog fail once the CA is critically
  close to expiry, so the problem cannot be silently ignored (use with care - see
  [Limitations](#limitations)).

## Setup

Install the module from the Forge or add it to your `Puppetfile`:

```puppet
mod 'martyewings-ca_expiry_check', '3.0.0'
```

Then classify the host(s) running your Puppet CA. Because the class is a no-op where the CA
certificate is absent, you can safely include it from a broad profile (e.g. your
`profile::puppet::server`).

## Usage

### Basic - notify when the CA is expiring

```puppet
include ca_expiry_check
```

With the defaults this emits a `notify` on each Puppet run once the CA is within **90 days** of
expiry, with a distinct CRITICAL message once within **14 days** (or already expired).

### Classify a specific node (site.pp)

```puppet
node 'primary.example.com' {
  include ca_expiry_check
}
```

### Tune the thresholds and actions

```puppet
class { 'ca_expiry_check':
  alertwindow       => 7776000,   # warn from 90 days out (seconds)
  critical_window   => 1209600,   # escalate the message from 14 days out (seconds)
  severity          => 'notify',  # action inside the warning window
  critical_severity => 'fail',    # block the catalog inside the critical window
}
```

### Configure via Hiera

```yaml
ca_expiry_check::alertwindow: 5184000      # 60 days
ca_expiry_check::critical_severity: 'fail'
```

### Export metrics for Prometheus node_exporter

```puppet
class { 'ca_expiry_check':
  manage_textfile => true,
  # textfile_path defaults to the node_exporter collector directory
}
```

Produces, e.g.:

```
puppet_ca_expiry_seconds 5184000
puppet_ca_expiry_days 60
puppet_ca_expired 0
```

### Write a JSON status report

```puppet
class { 'ca_expiry_check':
  manage_report => true,
}
```

Produces a JSON file containing the full `puppet_ca_expiry` fact (expiry date, seconds/days
remaining, expired flag, subject, issuer, serial and source path).

### Behaviour matrix

For each Puppet run on the CA host, exactly one action is taken based on where the certificate sits
relative to the thresholds:

| Certificate state | Action taken |
| ----------------- | ------------ |
| More than `alertwindow` seconds remaining | None |
| Within `alertwindow` but outside `critical_window` | `severity` (default `notify`) |
| Within `critical_window`, or already expired | `critical_severity` (default `notify`) |

Each action value means: `notify` - a `Notify` resource (shows as an event/change in reports and the
PE console); `warning` - a compilation warning in the Puppet logs; `fail` - the catalog fails to
compile; `none` - do nothing.

## Reference

See [REFERENCE.md](REFERENCE.md) for the auto-generated class reference. Key items below.

### Fact: `puppet_ca_expiry`

A structured fact, present **only** on hosts holding a Puppet CA certificate. Keys:

| Key | Type | Description |
| --- | ---- | ----------- |
| `expiry_date` | String | Expiry timestamp, ISO 8601 / UTC (machine-readable) |
| `expiry_date_human` | String | Expiry timestamp, human-readable UTC |
| `seconds_remaining` | Integer | Seconds until expiry (negative if expired) |
| `days_remaining` | Integer | Whole days until expiry |
| `expired` | Boolean | Whether the certificate has already expired |
| `subject` | String | Certificate subject DN |
| `issuer` | String | Certificate issuer DN |
| `serial` | String | Certificate serial number |
| `path` | String | Path the certificate was read from |

Inspect it on a CA host with:

```bash
puppet facts show puppet_ca_expiry
```

### Class: `ca_expiry_check`

| Parameter | Type | Default | Description |
| --------- | ---- | ------- | ----------- |
| `alertwindow` | `Integer[0]` | `7776000` (90d) | Warning threshold, in seconds before expiry |
| `critical_window` | `Optional[Integer[0]]` | `1209600` (14d) | Critical threshold, in seconds; `undef` disables the critical tier |
| `severity` | `Enum['notify','warning','fail','none']` | `notify` | Action in the warning window |
| `critical_severity` | `Enum['notify','warning','fail','none']` | `notify` | Action in the critical window / when expired |
| `manage_textfile` | `Boolean` | `false` | Write a Prometheus node_exporter textfile |
| `textfile_path` | absolute path | `/var/lib/node_exporter/textfile_collector/puppet_ca_expiry.prom` | Textfile destination |
| `manage_report` | `Boolean` | `false` | Write a JSON status report |
| `report_path` | absolute path | `/opt/puppetlabs/puppet/cache/state/puppet_ca_expiry.json` | JSON report destination |

`critical_window` must be less than or equal to `alertwindow`, or compilation fails with a clear
error.

## Upgrading from 2.x

Version 3.0.0 is a **breaking change**: the flat facts `ca_exp_date` and `ca_exp_seconds` have been
removed in favour of the single structured fact `puppet_ca_expiry`. Update any monitoring queries:

| 2.x | 3.x |
| --- | --- |
| `ca_exp_date` | `puppet_ca_expiry.expiry_date` (or `.expiry_date_human`) |
| `ca_exp_seconds` | `puppet_ca_expiry.seconds_remaining` |

The class parameter `alertwindow` is unchanged, so existing classification keeps working.

## Limitations

* The fact and class only act on the host(s) holding the Puppet CA certificate.
* `critical_severity => 'fail'` (and `severity => 'fail'`) will **stop the catalog applying** on the
  CA host while the condition holds. This guarantees the problem is noticed, but it also blocks other
  configuration on that node - including, potentially, a Puppet-driven CA renewal. The defaults use
  `notify` for this reason; opt into `fail` deliberately.
* When `manage_textfile` / `manage_report` are enabled, the destination's **parent directory must
  already exist** (the module does not manage it, to remain dependency-free).

## Development

This module uses the [Puppet Development Kit (PDK)](https://www.puppet.com/docs/pdk/3.x/pdk.html).

```bash
pdk validate --puppet-version 8   # metadata, puppet-lint, rubocop, epp
pdk test unit --puppet-version 8  # rspec-puppet + Facter unit tests
```

Pull requests are welcome at <https://github.com/MartyEwings/ca_expiry_check>.
