# frozen_string_literal: true

RSpec.shared_context "with nvim", :nvim do
  let(:nvim_mode) { :pipe }
  let(:nvim) { NeovimClient.new(nvim_mode) }
  let(:neogit_config) { "{}" }

  before { nvim.setup(neogit_config) }
  after { nvim.teardown }
end
