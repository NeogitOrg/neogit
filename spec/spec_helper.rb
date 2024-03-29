# frozen_string_literal: true

require "tmpdir"
require "git"
require "neovim"
require "debug"
require "active_support/all"

PROJECT_DIR = File.expand_path(File.join(__dir__, ".."))

Dir[File.join(File.expand_path("."), "spec", "support", "**", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  config.profile_examples = 10
  config.order = :random

  config.include Helpers

  config.around(:each) do |example|
    Dir.mktmpdir do |tmp|
      Dir.chdir(tmp) do
        Git.init
        example.run
      end
    end
  end
end
