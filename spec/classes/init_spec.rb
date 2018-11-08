require 'spec_helper'
describe 'hiera_aws_secretsmanager' do
  context 'with default values for all parameters' do
    it { should contain_class('hiera_aws_secretsmanager') }
  end
end
