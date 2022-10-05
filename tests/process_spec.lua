require("plenary.async").tests.add_to_env()
local eq = assert.are.same

local process = require("neogit.process")

describe("process execution", function()
  it("basic command", function()
    local result = process.new({ cmd = { "cat", "process_test" }, cwd = "./tests" }):spawn_blocking(1000)
    assert(result)
    assert.are.same(result.stdout, {
      "This is a test file",
      "It is intended to be read by cat and returned to neovim using the process api",
      "Blank lines will be stripped",
    })
  end)
  it("process input", function()
    local input = { "This is a line", "This is another line", "", "" }
    local result = process.new({ cmd = { "echo" }, input = input }):spawn_blocking(1000)
    assert(result)
    assert.are.same(
      result.stdout,
      vim.tbl_filter(function(v)
        return #v > 0
      end, input)
    )
  end)
end)
