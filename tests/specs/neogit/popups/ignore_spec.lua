require("plenary.async").tests.add_to_env()
local eq = assert.are.same
local operations = require("neogit.operations")
local harness = require("tests.util.git_harness")
local in_prepared_repo = harness.in_prepared_repo

local status = require("neogit.status")

local function act(normal_cmd)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(normal_cmd, true, true, true))
  vim.fn.feedkeys("", "x") -- flush typeahead
  status.wait_on_current_operation()
end

describe("ignore popup", function()
  it(
    "top level ignore",
    in_prepared_repo(function()
      local files = harness.exec { "git", "status", "--porcelain=1" }
      eq(files, { " M a.txt", "M  b.txt", "?? untracked.txt", "" })

      vim.fn.search("untracked.txt")

      act("V")

      act("it")

      operations.wait("ignore_shared")

      local files = harness.exec { "git", "status", "--porcelain=1" }

      eq(files, { " M a.txt", "M  b.txt", "?? .gitignore", "" })
      eq(harness.exec { "cat", ".gitignore" }, { "untracked.txt", "" })
    end)
  )
end)
