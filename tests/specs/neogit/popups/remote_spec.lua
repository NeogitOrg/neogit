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
      input.values = { "foo", "https://github.com/foo/bar" }
      act("Ma<cr>")

      operations.wait("add_remote")

      eq({ "foo", "origin" }, lib.git.remote.list())
      eq({ "https://github.com/foo/bar" }, lib.git.remote.get_url("foo"))

      input.values = { "other", "" }
      act("Ma<cr>")

      operations.wait("add_remote")

      eq({ "foo", "origin", "other" }, lib.git.remote.list())
      eq({ "git@github.com:other/example.git" }, lib.git.remote.get_url("other"))
    end)
  )
end)
