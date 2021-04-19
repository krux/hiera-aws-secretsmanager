class HieraAwsSecretsManagerHelper
  LIST_SECRETS_MAX = 100

  def initialize(options, puppet_context)
    @options = options
    @puppet_context = puppet_context

    unless @options.include? 'region'
      raise ArgumentError, 'options: {region: ...} must be set in hiera.yaml'
    end

    # No arguments being passed. We expect SDK configuration to
    # happen exclusively in the environment (including
    # $HOME/.aws/credentials, etc)
    @smclient = Aws::SecretsManager::Client.new(region: @options['region'])
    setup_stats_if_enabled
  end

  def lookup_key(key, options, context)
    unless @options.include? 'uri'
      raise ArgumentError, "either 'uri' or 'uris' must be set in hiera.yaml"
    end

    secret_name = "#{options['uri']}/#{key}"
    if secret_exists? secret_name then
      return cached_secret(secret_name)
    else
      return context.not_found
    end
  end

  private

  def setup_stats_if_enabled
    return unless @options['statsd'] == 'true'

    # smclient's class might not be constant due to mocking
    smclient_class = smclient.class

    # STATSD_ENV defaults to `development`. I don't know any other way
    # to set it so that Hiera inside Puppet Enterprise gets it.
    ENV['STATSD_ENV'] = 'production' unless ENV['STATSD_ENV']

    begin
      require 'statsd/instrument'
    rescue LoadError
      raise LoadError, 'hiera_aws_secretsmanager requires the statsd-instrument gem if statsd: true'
    end

    # Workaround for AWS SDK redefining Module#extend (:table-flip-emoji:)
    smclient_class.singleton_class.include StatsD::Instrument

    smclient_class.statsd_count :list_secrets, 'hiera_aws_secretsmanager.list_secrets'
    smclient_class.statsd_measure :list_secrets, 'hiera_aws_secretsmanager.list_secrets'
    smclient_class.statsd_count :get_secret_value, 'hiera_aws_secretsmanager.get_secret_value'
    smclient_class.statsd_measure :get_secret_value, 'hiera_aws_secretsmanager.get_secret_value'
  end
end
