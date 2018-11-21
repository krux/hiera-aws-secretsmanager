require 'spec_helper'

describe :hiera_aws_secretsmanager do
  it { should_not be_nil }
  it { should run.with_params().and_raise_error(ArgumentError) }

  context 'with existing key' do
    let (:key) { 'test::key' }
    let (:secret) { 'test-secret' }
    let (:options) { {} }
    let (:context) {
      double(Puppet::Pops::Lookup::Context).tap do |ctx|
        allow(ctx).to receive(:has_
      end
    }

    before do
      @smclient = instance_double(Aws::SecretsManager::Client)
      expect(Aws::SecretsManager::Client).to receive(:new).and_return(@smclient)
    end

    it 'returns the value of the key' do
      pending 'It turns out to be hard to test this :-('
      expect(@smclient).to receive(:get_secret_value)
                             .with(hash_including(secret_id: key))
                             .and_return(secret)

      expect(subject).to run.with_params(key, options, context).and_return(secret)
    end
  end
end
