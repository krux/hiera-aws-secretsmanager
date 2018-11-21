require 'spec_helper'
require 'pry'

require 'ostruct'

describe :hiera_aws_secretsmanager do
  context 'without arguments' do
    it { should_not be_nil }
    it { should run.with_params().and_raise_error(ArgumentError) }
  end

  context 'with an existing key' do
    let (:key) { 'test::key' }
    let (:options) { {'uri' => '/test/secret/path'} }

    let (:secret) { OpenStruct.new(name: secret_name, secret_string: secret_string) }
    let (:secret_name) { "#{options['uri']}/#{key}" }
    let (:secret_string) { 'test-secret' }

    let (:context) {
      double(Puppet::Pops::Lookup::Context).tap do |ctx|
        allow(ctx).to receive(:cache) do |key, value|
          @fake_cache[key] = value
        end

        allow(ctx).to receive(:cache_has_key) do |key|
          @fake_cache.key? key
        end

        allow(ctx).to receive(:cached_value) do |key|
          @fake_cache[key]
        end
      end
    }

    before do
      @smclient = instance_double(Aws::SecretsManager::Client)
      allow(Aws::SecretsManager::Client).to receive(:new).and_return(@smclient)
      @fake_cache = {
        '_hiera_aws_secretsmanager_smclient_' => @smclient,
      }
      allow(@smclient)
        .to receive(:list_secrets)
        .and_return(OpenStruct.new(secret_list: [secret]))

      allow(@smclient)
        .to receive(:get_secret_value)
        .with(hash_including(secret_id: secret_name))
        .and_return(secret)
    end

    context 'that is not cached' do
      it 'checks the cache first' do
        expect(context)
          .to receive(:cache_has_key)
          .with(secret_name)
          .and_return(false)

        expect(subject).to run.with_params(key, options, context)
      end

      it 'returns the value of the key' do
        expect(@smclient).to receive(:get_secret_value)
                               .with(hash_including(secret_id: key))
                               .and_return(secret)
        expect(subject).to run.with_params(key, options, context).and_return(secret)
      end
    end
  end
end
