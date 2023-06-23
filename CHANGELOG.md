# Changelog

All notable changes to this project will be documented in this file.

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
