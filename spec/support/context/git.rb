# frozen_string_literal: true

RSpec.shared_context "with git", :git do
  let(:git) { Git.open(Dir.pwd) }

  before do
    system("touch testfile")

    git.config("user.email", "test@example.com")
    git.config("user.name", "tester")
    git.add("testfile")
    git.commit("Initial commit")
  end
end
