require 'spec_helper'
require 'pry'

require 'ostruct'

describe :hiera_aws_secretsmanager do
  context 'without arguments' do
    it { should_not be_nil }
    it { should run.with_params().and_raise_error(ArgumentError) }
  end

  let (:key) { 'test::key' }
  let (:options) { {'uri' => '/test/secret/path'} }

  let (:context) {
    double(Puppet::Pops::Lookup::Context).tap do |ctx|
      allow(ctx).to receive(:cache) do |key, value|
        fake_cache[key] = value
      end

      allow(ctx).to receive(:cache_has_key) do |key|
        fake_cache.key? key
      end

      allow(ctx).to receive(:cached_value) do |key|
        fake_cache[key]
      end
    end
  }

  let (:fake_cache) {
    {
      smclient_key => smclient,
    }
  }

  let (:secret) { OpenStruct.new(name: secret_name, secret_string: secret_string) }
  let (:secret_name) { "#{options['uri']}/#{key}" }
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
    end
  }

  let (:smclient_key) { '_hiera_aws_secretsmanager_smclient_' }

  before do
    allow(Aws::SecretsManager::Client).to receive(:new).and_return(smclient)
  end

  context 'without a cached client' do
    it 'creates and caches a new client' do
      expect(context)
        .to receive(:cache_has_key)
        .with(smclient_key)
        .and_return(false).ordered

      expect(Aws::SecretsManager::Client)
        .to receive(:new)
        .and_return(smclient).ordered

      expect(context)
        .to receive(:cache)
        .with(smclient_key, smclient).ordered

      expect(subject).to run.with_params(key, options, context)
    end
  end

  context 'with a cached client' do
    it 'uses the cached client' do
      expect(Aws::SecretsManager::Client)
        .not_to receive(:new)

      expect(subject).to run.with_params(key, options, context)
    end
  end
  
  context 'with an existing key' do
    context 'that is not cached' do
      it 'checks the cache first' do
        expect(context)
          .to receive(:cache_has_key)
          .with(secret_name)
          .and_return(false).ordered

        expect(smclient).to receive(:list_secrets).ordered
        expect(smclient).to receive(:get_secret_value).ordered

        expect(subject).to run.with_params(key, options, context)
      end

      it 'returns the value of the key' do
        expect(smclient)
          .to receive(:get_secret_value)
          .with(hash_including(secret_id: secret_name))
          .and_return(secret)

        expect(subject).to run.with_params(key, options, context).and_return(secret_string)
      end
    end

    context 'that is cached' do
      let (:cached_secret) { 'cached-secret' }
      before do
        fake_cache[secret_name] = cached_secret
      end

      it 'returns the cached value without calling AWS' do
        expect(smclient).not_to receive(:list_secrets)
        expect(smclient).not_to receive(:get_secret_value)
        expect(subject)
          .to run
          .with_params(key, options, context)
          .and_return(cached_secret)
      end
    end
  end
end
