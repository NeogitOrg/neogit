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
      "",
    })
  end)
  it("process input", function()
    local input = { "This is a line", "This is another line", "", "" }
    local p = process.new { cmd = { "echo" } }
    p:spawn()
    p:send(table.concat(input, "\r\n"))
    p:close_stdin()
    local result = p:wait(1000)

    assert(result)
    assert.are.same(
      result.stdout,
      vim.tbl_filter(function(v)
        return #v > 0
      end, input)
    )
  end)

  it("process input", function()
    local input = { "This is a line", "This is another line", "", "" }
    local lines = {}
    local p = process.new {
      cmd = { "echo" },
      on_line = function(_, line)
        table.insert(lines, line)
      end,
    }

    p:spawn()
    p:send(table.concat(input, "\r\n"))
    p:close_stdin()
    local result = p:wait(1000)

    assert(result, vim.inspect(result))
    assert.are.same(lines, input)
  end)
  it("basic command", function()
    local result = process.new({ cmd = { "cat", "process_test" }, cwd = "./tests" }):spawn_blocking(1000)
    assert(result)
    assert.are.same(result.stdout, {
      "This is a test file",
      "It is intended to be read by cat and returned to neovim using the process api",
      "Blank lines will be stripped",
    })
  end)
end)
