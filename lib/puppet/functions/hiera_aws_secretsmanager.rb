Puppet::Functions.create_function(:hiera_aws_secretsmanager) do
  begin
    require 'aws-sdk-secretsmanager'
  rescue LoadError
    raise Puppet::DataBinding::LookupError, 'hiera_aws_secretsmanager requires the aws-sdk-secretsmanager gem installed'
  end

  dispatch :lookup_key do
    param 'String', :key
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  def lookup_key(key, options, context)
    context.not_found
  end

  private

  def smclient(_options, context)
    unless context.cache_has_value('smclient')
      # No arguments being passed. We expect SDK configuration to
      # happen outside of Puppet.
      smclient = Aws::SecretsManager::Client.new
      context.cache('smclient', smclient)
    end

    context.cached_value('smclient')
  end
end
