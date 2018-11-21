RSpec.configure do |c|
  c.mock_with :rspec
end

require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet'

require 'puppet/functions/hiera_aws_secretsmanager'

#require 'pry-rescue/rspec' rescue nil
