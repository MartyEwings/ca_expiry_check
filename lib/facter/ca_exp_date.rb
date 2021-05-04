Facter.add(:ca_exp_date) do
  confine do
    File.exist? '/etc/puppetlabs/puppet/ssl/ca/ca_crt.pem' or File.exist? '/etc/puppetlabs/puppetserver/ca/ca_crt.pem'
  end

  setcode do
    begin
      result = if File.exist? '/etc/puppetlabs/puppetserver/ca/ca_crt.pem'
                 Facter::Core::Execution.execute('/opt/puppetlabs/puppet/bin/openssl x509 -enddate -noout -in /etc/puppetlabs/puppetserver/ca/ca_crt.pem')
               else
                 Facter::Core::Execution.execute('/opt/puppetlabs/puppet/bin/openssl x509 -enddate -noout -in /etc/puppetlabs/puppet/ssl/ca/ca_crt.pem')
               end
      enddate = result.split('=')
      if enddate.empty?
        Facter.warn("No enddate found in #{result}")
      else
        enddate[1]
      end
    rescue Facter::Core::Execution::ExecutionFailure
      Facter.warn('Unable to execute the openssl command to check enddate')
    end
  end
end
