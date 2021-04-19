require_relative '../spec_helper'
require_relative '../../lib/hiera-aws-secretsmanager-helper'

describe HieraAwsSecretsManagerHelper do
  let (:key) { 'test::key' }
  let (:translated_key) { key.tr(':', '=') }
  let (:options) {
    {
      'uri' => 'test/secret/path',
      'region' => 'us-east-1',
      'statsd' => true,
    }
  }

  let (:context) {
    double(Puppet::Pops::Lookup::Context).tap do |ctx|
      allow(ctx).to receive(:cache).with(String, anything) do |key, value|
        fake_cache[key] = value
      end

      allow(ctx).to receive(:cache_has_key).with(String) do |key|
        fake_cache.key? key
      end

      allow(ctx).to receive(:cached_value).with(String) do |key|
        fake_cache[key]
      end

      allow(ctx).to receive(:explain) do
        if block_given?
          puts yield
        end
      end

      allow(ctx).to receive(:interpolate).with(anything) do |string|
        if string['%{'] then
          STDERR.puts <<~END

            WARNING: In order to test strings with Puppet
            interpolations, you have to define an allow(context).to
            receive(:interpolation) block in your local context.

          END
          "unexpected interpolation tag found in '#{string}'"
        else
          string
        end
      end
    end
  }

  let (:fake_cache) {
    {
      smclient_key => smclient,
    }
  }

  let (:secret) { OpenStruct.new(name: secret_name, secret_string: secret_string.to_json) }
  let (:secret_name) { "#{options['uri']}/#{translated_key}" }
  let (:secret_string) { 'test-secret' }

  let (:smclient) {
    instance_double(Aws::SecretsManager::Client).tap do |smclient|
      allow(smclient)
        .to receive(:list_secrets)
        .and_return(OpenStruct.new(secret_list: [secret]))

      allow(smclient)
        .to receive(:get_secret_value)
        .with(hash_including(secret_id: secret_name))
        .and_return(secret)

      # StatsD::Instrument needs this
      allow(smclient.class)
        .to receive(:method_defined?)
        .and_return(true)
    end
  }

  before do
    allow(Aws::SecretsManager::Client).to receive(:new).and_return(smclient)
  end

  describe '#initialize' do
    context 'with no region given' do
      before do
        options.delete('region')
      end

      it 'raises ArgumentError' do
        expect {
          asm = HieraAwsSecretsManagerHelper.new(options, context)
        }.to raise_error(ArgumentError)
      end
    end


  end
end
