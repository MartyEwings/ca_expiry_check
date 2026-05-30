require 'openssl'
require 'time'

# Structured fact describing the state of the Puppet CA certificate.
#
# Only resolves on hosts that actually host a Puppet CA (the fact is absent
# everywhere else, so consumers can simply test for its presence). The
# certificate is parsed natively with Ruby's OpenSSL bindings, so no shelling
# out to the openssl binary is required.
Facter.add(:puppet_ca_expiry) do
  # Candidate CA certificate locations, newest layout first:
  #   - Puppet 7+/8 and PE: managed by puppetserver
  #   - legacy: the old agent ssldir location
  ca_paths = [
    '/etc/puppetlabs/puppetserver/ca/ca_crt.pem',
    '/etc/puppetlabs/puppet/ssl/ca/ca_crt.pem',
  ]

  confine do
    ca_paths.any? { |path| File.exist?(path) }
  end

  setcode do
    ca_path = ca_paths.find { |path| File.exist?(path) }

    begin
      certificate = OpenSSL::X509::Certificate.new(File.read(ca_path))
      not_after = certificate.not_after
      seconds_remaining = (not_after - Time.now).to_i

      {
        'expiry_date'       => not_after.utc.iso8601,
        'expiry_date_human' => not_after.utc.to_s,
        'seconds_remaining' => seconds_remaining,
        'days_remaining'    => (seconds_remaining / 86_400.0).floor,
        'expired'           => Time.now > not_after,
        'subject'           => certificate.subject.to_s,
        'issuer'            => certificate.issuer.to_s,
        'serial'            => certificate.serial.to_s,
        'path'              => ca_path,
      }
    rescue OpenSSL::X509::CertificateError => e
      Facter.warn("puppet_ca_expiry: unable to parse CA certificate at #{ca_path}: #{e.message}")
      nil
    rescue SystemCallError => e
      Facter.warn("puppet_ca_expiry: unable to read CA certificate at #{ca_path}: #{e.message}")
      nil
    end
  end
end
