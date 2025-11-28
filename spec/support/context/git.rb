# frozen_string_literal: true

RSpec.shared_context "with git", :git do
  let(:git) { Git.open(Dir.pwd) }

  before do
    git.config("user.email", "test@example.com")
    git.config("user.name", "tester")

    create_file("testfile", "hello, world\n")
    git.add("testfile")
    git.commit("Initial commit\ncommit message")
  end
end
