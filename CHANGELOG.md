# Changelog

All notable changes to this project will be documented in this file.

## Release 3.0.0

**Features**

- New structured fact `puppet_ca_expiry` exposing `expiry_date`, `expiry_date_human`,
  `seconds_remaining`, `days_remaining`, `expired`, `subject`, `issuer`, `serial` and `path`.
- Configurable alerting: independent `severity` (warning window) and `critical_severity`
  (critical window / expired) actions - `notify`, `warning`, `fail` or `none`.
- Second `critical_window` threshold in addition to the existing `alertwindow`.
- Optional Prometheus node_exporter textfile output (`manage_textfile`).
- Optional JSON status report output (`manage_report`).
- Refreshed operating system support (RHEL/Alma/Rocky/Oracle 8-10, CentOS 9, Debian 11-12,
  Ubuntu 20.04-24.04, SLES 15) and modern PDK scaffolding. Remains dependency-free.

**Breaking changes**

- The flat facts `ca_exp_date` and `ca_exp_seconds` have been removed and replaced by the single
  structured fact `puppet_ca_expiry`. Update any monitoring queries accordingly. The CA cert
  expiry date and seconds-remaining are now `puppet_ca_expiry.expiry_date` /
  `puppet_ca_expiry.seconds_remaining`.
- Dropped Puppet 7 support. The requirement is now `>= 8.0.0 < 10.0.0` (Puppet 8, and Puppet 9
  when released). For Puppet 7 / PE 2023.x estates, stay on 2.0.0.

## Release 2.0.0

**Features**
Puppet 8 compatibility

***Deprecations***

Dropped support for puppet 4,5,6


## Release 1.1.0

**Features**
Updated module to consider the new location of the CA directory in Puppet 7

## Release 1.0

**Features**
Cleaned up Readme


## Release 0.1.1

**Features**
Removed some of the external shell requirements on the facts

**Bugfixes**

Properly confined to only CA hosts

By moving the confinement to the actual CA Cert

/etc/puppetlabs/puppet/ssl/ca/ca_crt.pem

**Known Issues**
