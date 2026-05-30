require 'spec_helper'

describe 'ca_expiry_check' do
  let(:node) { 'ca.example.com' }

  # Build a puppet_ca_expiry fact value a given number of days from expiry.
  def ca_fact(days)
    seconds = (days * 86_400).to_i
    {
      'expiry_date'       => '2026-12-01T00:00:00Z',
      'expiry_date_human' => '2026-12-01 00:00:00 UTC',
      'seconds_remaining' => seconds,
      'days_remaining'    => days.floor,
      'expired'           => seconds <= 0,
      'subject'           => '/CN=Puppet CA: ca.example.com',
      'issuer'            => '/CN=Puppet CA: ca.example.com',
      'serial'            => '1',
      'path'              => '/etc/puppetlabs/puppetserver/ca/ca_crt.pem',
    }
  end

  context 'on a node without a Puppet CA (fact absent)' do
    let(:facts) { { os: { family: 'RedHat' } } }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.not_to contain_notify('ca_expiry_check') }
  end

  context 'on a CA host' do
    context 'well outside the warning window (200 days)' do
      let(:facts) { { puppet_ca_expiry: ca_fact(200) } }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.not_to contain_notify('ca_expiry_check') }
    end

    context 'inside the warning window (60 days), default severity notify' do
      let(:facts) { { puppet_ca_expiry: ca_fact(60) } }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_notify('ca_expiry_check').with_message(%r{WARNING.*60 days}) }
    end

    context 'inside the critical window (5 days), default critical_severity notify' do
      let(:facts) { { puppet_ca_expiry: ca_fact(5) } }

      it { is_expected.to contain_notify('ca_expiry_check').with_message(%r{CRITICAL.*5 days}) }
    end

    context 'expired' do
      let(:facts) { { puppet_ca_expiry: ca_fact(-1) } }

      it { is_expected.to contain_notify('ca_expiry_check').with_message(%r{EXPIRED}) }
    end

    context 'critical_severity => fail inside the critical window' do
      let(:facts) { { puppet_ca_expiry: ca_fact(5) } }
      let(:params) { { critical_severity: 'fail' } }

      it { is_expected.to compile.and_raise_error(%r{CRITICAL}) }
    end

    context 'severity => none in the warning window' do
      let(:facts) { { puppet_ca_expiry: ca_fact(60) } }
      let(:params) { { severity: 'none' } }

      it { is_expected.not_to contain_notify('ca_expiry_check') }
    end

    context 'critical_window > alertwindow is rejected' do
      let(:facts) { { puppet_ca_expiry: ca_fact(60) } }
      let(:params) { { alertwindow: 100, critical_window: 200 } }

      it { is_expected.to compile.and_raise_error(%r{must be less than or equal}) }
    end

    context 'manage_textfile => true' do
      let(:facts) { { puppet_ca_expiry: ca_fact(60) } }
      let(:params) { { manage_textfile: true } }

      it {
        is_expected.to contain_file('/var/lib/node_exporter/textfile_collector/puppet_ca_expiry.prom')
          .with_content(%r{puppet_ca_expiry_seconds \d+})
          .with_content(%r{puppet_ca_expired 0})
      }
    end

    context 'manage_report => true' do
      let(:facts) { { puppet_ca_expiry: ca_fact(60) } }
      let(:params) { { manage_report: true } }

      it {
        is_expected.to contain_file('/opt/puppetlabs/puppet/cache/state/puppet_ca_expiry.json')
          .with_content(%r{"seconds_remaining": \d+})
          .with_content(%r{"expired": false})
      }
    end
  end
end
