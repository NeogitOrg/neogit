require("plenary.async").tests.add_to_env()
local eq = assert.are.same
local operations = require("neogit.operations")
local harness = require("tests.util.git_harness")
local in_prepared_repo = harness.in_prepared_repo

local status = require("neogit.status")
local input = require("tests.mocks.input")
local lib = require("neogit.lib")

local function act(normal_cmd)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(normal_cmd, true, true, true))
  vim.fn.feedkeys("", "x") -- flush typeahead
  status.wait_on_current_operation()
end

describe("remote popup", function()
  it(
    "can add remote",
    in_prepared_repo(function()
      local remote_a = harness.prepare_repository()
      local remote_b = harness.prepare_repository()

      input.values = { "foo", remote_a }
      act("Ma")

      operations.wait("add_remote")

      eq({ "foo", "origin" }, lib.git.remote.list())
      eq({ remote_a }, lib.git.remote.get_url("foo"))

      input.values = { "other", remote_b }
      act("Ma")

      operations.wait("add_remote")

      eq({ "foo", "origin", "other" }, lib.git.remote.list())
      eq({ remote_b }, lib.git.remote.get_url("other"))
    end)
  )
end)
