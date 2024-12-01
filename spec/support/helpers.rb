# frozen_string_literal: true

module Helpers
  def create_file(filename, content = "")
    File.write(File.join(Dir.pwd, filename), content)
  end

  def expect_git_failure(&)
    expect(&).to raise_error(Git::FailedError)
  end

  def await # rubocop:disable Metrics/MethodLength
    last_error = nil
    success = false

    10.times do
      yield
      success = true
      break
    rescue RSpec::Expectations::ExpectationNotMetError => e
      last_error = e
      sleep 0.1
    end

    raise last_error if !success && last_error
  end
end
