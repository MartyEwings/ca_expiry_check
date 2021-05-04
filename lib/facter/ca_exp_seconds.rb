require 'openssl'
require 'time'

Facter.add(:ca_exp_seconds) do
  confine do
    File.exist? '/etc/puppetlabs/puppet/ssl/ca/ca_crt.pem' or File.exist? '/etc/puppetlabs/puppetserver/ca/ca_crt.pem'
  end
  setcode do
    raw_ca_cert = if File.exist? '/etc/puppetlabs/puppetserver/ca/ca_crt.pem'
                    File.read '/etc/puppetlabs/puppetserver/ca/ca_crt.pem'
                  else
                    File.read '/etc/puppetlabs/puppet/ssl/ca/ca_crt.pem'
                  end
    certificate = OpenSSL::X509::Certificate.new raw_ca_cert
    certificate.not_after - Time.now
  end
end
