# @summary Monitor and alert on impending Puppet CA certificate expiry.
#
# Consumes the `puppet_ca_expiry` structured fact (present only on Puppet CA
# hosts) and surfaces an alert as the certificate approaches expiry. Two
# thresholds are supported - a warning window and a tighter critical window -
# each with an independently configurable action (a Puppet `notify` resource,
# a compilation `warning`, a hard `fail`, or nothing).
#
# Optionally it can also write the expiry data to a Prometheus node_exporter
# textfile and/or a JSON status file for consumption by external monitoring.
#
# The class is a no-op on any node where the `puppet_ca_expiry` fact is absent,
# so it is safe to classify broadly (for example via the `puppet` role).
#
# @example Defaults (notify within 90 days, dedicated message within 14 days)
#   include ca_expiry_check
#
# @example Hard-fail the catalog once inside the critical window
#   class { 'ca_expiry_check':
#     critical_severity => 'fail',
#   }
#
# @example Expose metrics to Prometheus node_exporter
#   class { 'ca_expiry_check':
#     manage_textfile => true,
#   }
#
# @param alertwindow
#   Warning threshold, in seconds before expiry, at which alerting begins.
#   Defaults to 7776000 (90 days).
# @param critical_window
#   Critical threshold, in seconds before expiry, at which `critical_severity`
#   takes over from `severity`. Must be less than or equal to `alertwindow`.
#   Set to `undef` to disable the critical tier. Defaults to 1209600 (14 days).
# @param severity
#   Action taken while within the warning window (but outside the critical
#   window): `notify`, `warning`, `fail` or `none`. Defaults to `notify`.
# @param critical_severity
#   Action taken while within the critical window, or once the CA has expired.
#   Defaults to `notify`. Set to `fail` to block catalog application until the
#   CA is renewed (use with care on a primary server).
# @param manage_textfile
#   Whether to write a Prometheus node_exporter textfile. Defaults to `false`.
# @param textfile_path
#   Absolute path for the node_exporter textfile. The parent directory is
#   expected to already exist.
# @param manage_report
#   Whether to write a JSON status report. Defaults to `false`.
# @param report_path
#   Absolute path for the JSON status report. The parent directory is expected
#   to already exist.
class ca_expiry_check (
  Integer[0]                             $alertwindow       = 7776000,
  Optional[Integer[0]]                   $critical_window   = 1209600, # lint:ignore:optional_default undef disables the critical tier
  Enum['notify', 'warning', 'fail', 'none'] $severity          = 'notify',
  Enum['notify', 'warning', 'fail', 'none'] $critical_severity = 'notify',
  Boolean                                $manage_textfile   = false,
  Pattern[/\A\//]                        $textfile_path     = '/var/lib/node_exporter/textfile_collector/puppet_ca_expiry.prom',
  Boolean                                $manage_report     = false,
  Pattern[/\A\//]                        $report_path       = '/opt/puppetlabs/puppet/cache/state/puppet_ca_expiry.json',
) {
  if $critical_window =~ Integer and $critical_window > $alertwindow {
    fail("ca_expiry_check: critical_window (${critical_window}) must be less than or equal to alertwindow (${alertwindow})")
  }

  $ca = $facts['puppet_ca_expiry']

  # No-op on nodes that do not host a Puppet CA.
  if $ca =~ Hash {
    $seconds = $ca['seconds_remaining']
    $days    = $ca['days_remaining']
    $date    = $ca['expiry_date']

    $in_critical = $ca['expired'] or ($critical_window =~ Integer and $seconds < $critical_window)
    $in_warning  = $seconds < $alertwindow

    if $in_critical {
      $action  = $critical_severity
      $message = $ca['expired'] ? {
        true    => "Puppet CA certificate EXPIRED on ${date}. Renew the CA immediately.",
        default => "CRITICAL: Puppet CA certificate expires on ${date} (${days} days). Renew the CA now.",
      }
    } elsif $in_warning {
      $action  = $severity
      $message = "WARNING: Puppet CA certificate expires on ${date} (${days} days). Plan a CA renewal."
    } else {
      $action  = 'none'
      $message = undef
    }

    case $action {
      'notify': {
        notify { 'ca_expiry_check': message => $message }
      }
      'warning': {
        warning($message)
      }
      'fail': {
        fail($message)
      }
      default: {
        # 'none' or outside all windows: nothing to surface.
      }
    }

    if $manage_textfile {
      file { $textfile_path:
        ensure  => file,
        content => epp('ca_expiry_check/node_exporter.prom.epp', { 'ca' => $ca }),
      }
    }

    if $manage_report {
      file { $report_path:
        ensure  => file,
        content => epp('ca_expiry_check/report.json.epp', { 'ca' => $ca }),
      }
    }
  }
}
