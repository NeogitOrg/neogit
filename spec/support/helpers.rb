# frozen_string_literal: true

module Helpers
  def create_file(filename, content = "")
    File.write(File.join(Dir.pwd, filename), content)
  end

  def expect_git_failure(&)
    expect(&).to raise_error(Git::FailedError)
  end

  # def wait_for_expect
  #   last_error = nil
  #   success = false
  #
  #   5.times do
  #     begin
  #       yield
  #       success = true
  #       break
  #     rescue RSpec::Expectations::ExpectationNotMetError => e
  #       last_error = e
  #       sleep 0.5
  #     end
  #   end
  #
  #   raise last_error if !success && last_error
  # end
end
