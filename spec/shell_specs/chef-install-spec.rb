require 'rspec/shell/expectations'
$:.unshift File.expand_path('../../ChefExtensionHandler', __FILE__)

describe 'Chef Install' do
  include Rspec::Shell::Expectations

  let(:stubbed_env) { create_stubbed_env }

  it 'Installs chef for linux' do
    stdout, stderr, status = stubbed_env.execute(
      'bin/chef-install.sh',
      { 'SOME_OPTIONAL' => 'env vars' }
    )
    expect(status.exitstatus).to eq 0
  end
end