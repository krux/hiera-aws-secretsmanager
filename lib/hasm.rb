class HASM
  LIST_SECRETS_MAX = 100

  # Raised if secret is not found
  class NotFound; end

  def initialize(options, context)
    @options = options
    @context = context

    initialize_smclient
    cache_secret_list
  end

  def secret_value(secret_name)
    secret_list.member?(secret_name) && @smclient.get_secret_value(secret_id: secret_name)
    raise NotFound
  end

  private

  def secret_list
    @secret_list || load_secret_list
  end

  def load_secret_list
    @secret_list = []

    # SDK handles retry and pagination
    @smclient.list_secrets(max_results: LIST_SECRETS_MAX).each do |batch|
      @secret_list.concat batch.secret_list.map(&:name)
    end
    @secret_list
  end

  def initialize_smclient
    unless @options.include? 'region'
      raise ArgumentError, 'hiera_aws_secretsmanager requires options.region to be set in hiera.yaml'
    end

    begin
      require 'aws-sdk-secretsmanager'
    rescue LoadError => e
      raise e, 'hiera_aws_secretsmanager requires the aws-sdk-secretsmanager gem installed'
    end

    @smclient = Aws::SecretsManager::Client.new(region: @options['region'])
    setup_stats_if_enabled
  end

  def setup_stats_if_enabled
    return unless @options['statsd']

    # smclient's class might not be constant due to mocking
    smclient_class = smclient.class

    # STATSD_ENV defaults to `development`. I don't know any other way
    # to set it so that Hiera inside Puppet Enterprise gets it.
    ENV['STATSD_ENV'] = 'production' unless ENV['STATSD_ENV']

    begin
      require 'statsd/instrument'
    rescue LoadError => e
      raise e, 'hiera_aws_secretsmanager requires the statsd-instrument gem if option statsd: true'
    end

    # Workaround for AWS SDK redefining Module#extend (:table-flip-emoji:)
    smclient_class.singleton_class.include StatsD::Instrument

    smclient_class.statsd_count :list_secrets, 'hiera_aws_secretsmanager.list_secrets'
    smclient_class.statsd_measure :list_secrets, 'hiera_aws_secretsmanager.list_secrets'
    smclient_class.statsd_count :get_secret_value, 'hiera_aws_secretsmanager.get_secret_value'
    smclient_class.statsd_measure :get_secret_value, 'hiera_aws_secretsmanager.get_secret_value'
  end
end
