# frozen_string_literal: true

RSpec.shared_context "nvim", :nvim do
  let(:nvim) { NeovimClient.new }

  before { nvim.setup }
  after { nvim.teardown }
end
