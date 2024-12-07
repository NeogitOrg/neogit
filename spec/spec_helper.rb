# frozen_string_literal: true

require "tmpdir"
require "git"
require "neovim"
require "debug"
require "active_support/all"
require "timeout"

ENV["GIT_CONFIG_GLOBAL"] = ""

PROJECT_DIR = File.expand_path(File.join(__dir__, "..")) unless defined?(PROJECT_DIR)

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

  config.before(:suite) { puts "\e[?25l" } # Hide Cursor
  config.after(:suite)  { puts "\e[?25h" } # Show Cursor

  config.around do |example|
    with_remote = example.metadata.fetch(:with_remote_origin, false)

    Dir.mktmpdir do |local|
      Dir.mktmpdir do |remote|
        Git.init(remote, { bare: true }) if with_remote

        Dir.chdir(local) do
          local_repo = Git.init
          local_repo.add_remote("origin", remote) if with_remote
          example.run
        end
      end
    end
  end

  # config.around do |example|
  #   Timeout.timeout(10) { example.call }
  # end
end
