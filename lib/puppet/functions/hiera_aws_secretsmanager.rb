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
  dispatch :lookup_key do
    param 'String', :key
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  def lookup_key(key, options, context)
    @context = context
    @options = options

    begin
      cached_secret(key)
    rescue HASM::NotFound
      context.not_found
    end
  end

  private

  def hasm
    if @context.cache_has_key(hasm_cache_key) then
      @context.cached_value(hasm_cache_key)
    else
      begin
        require_relative '../../hasm'
      rescue LoadError, ArgumentError => e
        raise Puppet::DataBinding::LookupError, "hiera_aws_secretsmanager: #{e.message}"
      end

      @context.cache(hasm_cache_key, HASM.new(@options, @context))
    end
  end

  def hasm_cache_key
    '__hasm_instance'
  end

  def cached_secret(key)
    secret_name = secret_name(key)

    @context.explain { "looking up #{secret_name}" }
    if @context.cache_has_key secret_name then
      @context.explain { "returning cached #{secret_name}" }
      @context.cached_value(secret_name)
    else
      secret_value = hasm.secret_value(secret_name)
      @context.explain { "found #{secret_name}\n#{secret_value.inspect}" }

      interpolated_string = @context.interpolate(secret_value.secret_string)
      @context.explain { "after interpolation:\n#{interpolated_string.inspect}" }

      secret_object = JSON.parse(interpolated_string)
      @context.explain { "after json parsing:\n#{secret_object.inspect}" }

      @context.explain { "caching new #{secret_name}" }
      @context.cache(secret_name, secret_object)
    end
  end

  def secret_name(key)
    unless @options.include? 'uri'
      raise ArgumentError, "either 'uri' or 'uris' must be set in hiera.yaml"
    end

    "#{@options['uri']}/#{key}"
  end
end
