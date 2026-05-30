require 'spec_helper'
require 'openssl'

describe 'puppet_ca_expiry fact', type: :fact do
  subject(:fact) { Facter.fact(:puppet_ca_expiry).value }

  let(:ca_path) { '/etc/puppetlabs/puppetserver/ca/ca_crt.pem' }
  let(:legacy_path) { '/etc/puppetlabs/puppet/ssl/ca/ca_crt.pem' }

  # Generate a self-signed certificate valid for the given number of days.
  def build_cert(days_valid)
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 42
    name = OpenSSL::X509::Name.parse('/CN=Puppet CA: test')
    cert.subject = name
    cert.issuer = name
    cert.public_key = key.public_key
    cert.not_before = Time.now - 86_400
    cert.not_after = Time.now + (days_valid * 86_400)
    cert.sign(key, OpenSSL::Digest.new('SHA256'))
    cert
  end

  before(:each) do
    Facter.clear
    # Default: no CA cert present anywhere.
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(ca_path).and_return(false)
    allow(File).to receive(:exist?).with(legacy_path).and_return(false)
  end

  after(:each) { Facter.clear }

  context 'when no CA certificate is present' do
    it 'does not resolve' do
      expect(fact).to be_nil
    end
  end

  context 'with a valid CA certificate at the puppetserver path' do
    let(:cert) { build_cert(100) }

    before(:each) do
      allow(File).to receive(:exist?).with(ca_path).and_return(true)
      allow(File).to receive(:read).with(ca_path).and_return(cert.to_pem)
    end

    it { expect(fact['expired']).to be(false) }
    it { expect(fact['days_remaining']).to be_within(1).of(99) }
    it { expect(fact['seconds_remaining']).to be > 0 }
    it { expect(fact['path']).to eq(ca_path) }
    it { expect(fact['serial']).to eq('42') }
    it { expect(fact['subject']).to match(%r{Puppet CA: test}) }
    it { expect(fact['expiry_date']).to match(%r{\A\d{4}-\d{2}-\d{2}T}) }
  end

  context 'with an expired CA certificate' do
    let(:cert) { build_cert(-1) }

    before(:each) do
      allow(File).to receive(:exist?).with(ca_path).and_return(true)
      allow(File).to receive(:read).with(ca_path).and_return(cert.to_pem)
    end

    it { expect(fact['expired']).to be(true) }
    it { expect(fact['seconds_remaining']).to be < 0 }
  end

  context 'falling back to the legacy ssldir path' do
    let(:cert) { build_cert(30) }

    before(:each) do
      allow(File).to receive(:exist?).with(legacy_path).and_return(true)
      allow(File).to receive(:read).with(legacy_path).and_return(cert.to_pem)
    end

    it { expect(fact['path']).to eq(legacy_path) }
  end

  context 'with an unparseable certificate' do
    before(:each) do
      allow(File).to receive(:exist?).with(ca_path).and_return(true)
      allow(File).to receive(:read).with(ca_path).and_return('not a certificate')
    end

    it 'warns and does not resolve' do
      expect(fact).to be_nil
    end
  end
end
