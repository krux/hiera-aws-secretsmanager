ENV['STATSD_ENV'] = 'development'
require 'statsd/instrument'

RSpec.configure do |c|
  c.mock_with :rspec
  c.include StatsD::Instrument::Matchers
  c.example_status_persistence_file_path = ".rspec_status"
end

require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet'

require 'puppet/functions/hiera_aws_secretsmanager'
