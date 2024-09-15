# frozen_string_literal: true

RSpec.shared_context "with nvim", :nvim do
  let(:nvim) { NeovimClient.new }
  let(:neogit_config) { "{}" }

  before { nvim.setup(neogit_config) }
  after  { nvim.teardown }
end
