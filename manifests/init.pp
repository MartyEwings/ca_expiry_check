# Notify if CA will expire within a set window
#
# Notifys on each puppet run should the CA Cert get within a specific window
#
# @example
#   include ca_expiry_check
# @param [Integer] alertwindow
#  Integer value representing number of seconds prior to CA expiry alerts should trigger, defaults to 90 days
class ca_expiry_check (
  Integer $alertwindow,
) {
  if $facts[ca_exp_seconds] < $ca_expiry_check::alertwindow {
    notify { "Puppet CA expiring on ${facts['ca_exp_date']} You should renew": }
} }
