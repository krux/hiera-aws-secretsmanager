require 'puppet'
require 'puppet/functions'

require 'json'

Puppet::Functions.create_function(:hiera_aws_secretsmanager) do
  # An implementation of a lookup_key Puppet Function for Hiera.
  # Looks up keys in AWS Secrets Manager.
  #
  # @param base Hiera key, e.g. `mydb::myuser::mypassword`
  #
  # @option options 'uri' contains an interpolated value from the uris
  # list in hiera.yaml. Puppet handles iterating over all possible
  # interpolations for us, yay!
  #
  # @param A Puppet::LookupContext passed from Puppet
  #
  # (The type of :context SHOULD be Puppet::LookupContext, but it is
  # ridiculously hard to instantiate or mock a Puppet::LookupContext
  # from RSpec, so this is a stupid workaround. I ... hope(?)  this
  # bug will contain the fix that allows creating a real
  # Puppet::LookupContext.)
  dispatch :lookup_key do
    param 'String', :key
    param 'Hash', :options
    param 'Any', :context
  end

  begin
    require 'aws-sdk-secretsmanager'
  rescue LoadError
    raise Puppet::DataBinding::LookupError, 'hiera_aws_secretsmanager requires the aws-sdk-secretsmanager gem installed'
  end

  # Lame explicit check for already defined constants courtesy of
  # Puppet feeling the need to reload this file over and over.
  unless defined? LIST_SECRETS_MAX
    LIST_SECRETS_MAX = 100
    SMCLIENT_KEY = '_hiera_aws_secretsmanager_smclient_'.freeze
  end

  @secrets_list = nil

  def lookup_key(key, options, context)
    # Secrets Manager does not allow ':' in secret names, so we
    # translate them here. We choose '=' merely because it is
    # graphically similar to ':'. This could be amended to
    # quoted-printable in the future if needed.
    key = key.dup.tr(':', '=')

    @context = context
    @options = options

    unless options.include? 'uri'
      raise ArgumentError, "either 'uri' or 'uris' must be set in hiera.yaml"
    end

    setup_stats_if_enabled

    secret_name = "#{options['uri']}/#{key}"
    if secret_exists? secret_name then
      return cached_secret(secret_name)
    else
      return @context.not_found
    end
  end

  private

  def smclient
    unless @context.cache_has_key(SMCLIENT_KEY)
      # No arguments being passed. We expect SDK configuration to
      # happen exclusively in the environment (including
      # $HOME/.aws/credentials, etc)
      unless @options.key? 'region'
        raise ArgumentError, 'options: {region: ...} must be set in hiera.yaml'
      end

      @context.cache(SMCLIENT_KEY, Aws::SecretsManager::Client.new(smclient_options))
    end

    @context.cached_value(SMCLIENT_KEY)
  end

  def smclient_options
    smclient_options = {region: @options['region']}
    smclient_options.merge!(retry_options)
    smclient_options.merge!(endpoint_options)
    @context.explain { "Aws::SecretsManager::Client options: #{smclient_options}" }
    smclient_options
  end

  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/SecretsManager/Client.html#initialize-instance_method
  def retry_options
    return {} unless @options['retries']

    allowed_opts = %w[
      adaptive_retry_wait_to_fill
      max_attempts
      retry_backoff
      retry_base_delay
      retry_jitter
      retry_limit
      retry_max_delay
      retry_mode
    ]

    @options['retries']
      .select { |opt, _| allowed_opts.member?(opt) }
      .transform_keys!(&:to_sym)
  end

  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/SecretsManager/Client.html#initialize-instance_method
  def endpoint_options
    return {} unless @options['endpoint']

    allowed_opts = %w[
      endpoint
      endpoint_cache_max_entries
      endpoint_cache_max_threads
      endpoint_cache_poll_interval
      endpoint_discovery
    ]

    @options['endpoint']
      .select { |opt, _| allowed_opts.member?(opt) }
      .transform_keys!(&:to_sym)
  end

  def setup_stats_if_enabled
    return unless @options['statsd']

    # smclient's class might not be constant due to mocking
    smclient_class = smclient.class

    # Guard due to module reloading
    return if smclient_class.class_variable_defined?(:@@__hasm_stats_setup_done)
    smclient_class.class_variable_set(:@@__hasm_stats_setup_done, true)

    # STATSD_ENV defaults to `development`. I don't know any other way
    # to set it so that Hiera inside Puppet Enterprise gets it.
    ENV['STATSD_ENV'] = 'production' unless ENV['STATSD_ENV']

    begin
      require 'statsd/instrument'
    rescue LoadError
      raise Puppet::DataBinding::LookupError, 'hiera_aws_secretsmanager requires the statsd-instrument gem if statsd: true'
    end

    # Workaround for AWS SDK redefining Module#extend (:table-flip-emoji:)
    smclient_class.singleton_class.include StatsD::Instrument

    smclient_class.statsd_count :list_secrets, 'hiera_aws_secretsmanager.list_secrets'
    smclient_class.statsd_measure :list_secrets, 'hiera_aws_secretsmanager.list_secrets'
    smclient_class.statsd_count :get_secret_value, 'hiera_aws_secretsmanager.get_secret_value'
    smclient_class.statsd_measure :get_secret_value, 'hiera_aws_secretsmanager.get_secret_value'
  end

  def cached_secret(secret_name)
    unless @context.cache_has_key(secret_name)
      secret = smclient.get_secret_value(secret_id: secret_name)
      @context.explain { "Found secret: #{secret_name}\n#{secret.inspect}" }

      interpolated_string = @context.interpolate(secret.secret_string)

      if JSON::VERSION_MAJOR < 2 then # Gross but we had to punt.
        secret_object = JSON.parse(interpolated_string, quirks_mode: true)
      else
        secret_object = JSON.parse(interpolated_string)
      end

      @context.explain { "Secret parsed as JSON:\n#{secret_object.inspect}" }
      @context.cache(secret_name, secret_object)
    end

    @context.cached_value(secret_name)
  end

  def cached_secrets_list
    unless @secrets_list
      @context.explain { "SecretsList not cached. Listing all secrets." }
      batch = smclient.list_secrets(max_results: LIST_SECRETS_MAX)
      @secrets_list = batch.secret_list.map(&:name)
      while batch.next_token do
        batch = smclient.list_secrets(max_results: LIST_SECRETS_MAX, next_token: batch.next_token)
        @secrets_list.concat batch.secret_list.map(&:name)
      end
    end
    @secrets_list
  end

  def secret_exists?(secret_name)
    @context.cache_has_key(secret_name) or cached_secrets_list.include? secret_name
  end
end
