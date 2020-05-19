# ca_expiry_check


#### Table of Contents

1. [Description](#description)
2. [Usage - Configuration options and additional functionality](#usage)
3. [Reference - An under-the-hood peek at what the module is doing and how](#reference)

## Description

This Module Provides facts and a class that are designed to inform and notify in the instance the Puppet CA is due to expire 

## Usage

The Facts contained in this module can be used for direct consumption by monitoring tools such as Splunk.

Alternativly assigning the class ca_expiry_check to nodes running a Puppet CA, Will "Notify" on Each Puppet run as soon as the certificate expiry is within a designated window.
This window by default is 90 days, but is configurable through the use of the "alertwindow" parameter which takes an integer representing the desired alert window in seconds

### Class Delcaration *Optional.*

To activate the notification functions of this module, classify your Primary Master (or which ever server hosts your main Puppet CA) with the ca_expiry_check class using your preferred classification method. Below is an example using site.pp.

node 'master.example.com' {
  include ca_expiry_check
}

To optionally configure the length of the window in which you are notified of impending expiry away from the default of 90 days, add the `alertwindow` parameter with a value in seconds to your classification.


class { 'ca_expiry_check':

  alertwindow              => 15552000,

}


#### Outputs

When the class is included once within the alert window period, there will be a corrective change, in the form of a notify, with the following messaging":

`Puppet CA expiring on ${facts['ca_exp_date']} You should renew`


## Reference

### Facts: 

#### `ca_exp_date`

Prints the expiry date of the CA, confined to run only on Puppet Servers hosting the CA

#### `ca_exp_seconds`

Prints the number of seconds between now() and $ca_exp_date, confined to run only on Puppet Servers hosting the CA

#### Parameters:

##### `alertwindow`

*Optional.* Provides a method to alter the notification window value in seconds. Valid options: integer . Default value: 7776000 (90 days).






