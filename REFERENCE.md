# Reference

<!-- DO NOT EDIT: This document was generated by Puppet Strings -->

## Table of Contents

### Classes

* [`ca_expiry_check`](#ca_expiry_check): Notify if CA will expire within a set window  Notifys on each puppet run should the CA Cert get within a specific window

## Classes

### <a name="ca_expiry_check"></a>`ca_expiry_check`

Notify if CA will expire within a set window

Notifys on each puppet run should the CA Cert get within a specific window

#### Examples

##### 

```puppet
include ca_expiry_check
```

#### Parameters

The following parameters are available in the `ca_expiry_check` class:

* [`alertwindow`](#alertwindow)

##### <a name="alertwindow"></a>`alertwindow`

Data type: `Integer`



