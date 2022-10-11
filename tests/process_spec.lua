require("plenary.async").tests.add_to_env()
local eq = assert.are.same

local process = require("neogit.process")

describe("process execution", function()
  it("basic command", function()
    local result = process.new({ cmd = { "cat", "process_test" }, cwd = "./tests" }):spawn_blocking(1000)
    assert(result)
    assert.are.same(result.stdout, {
      "This is a test file",
      "",
      "",
      "It is intended to be read by cat and returned to neovim using the process api",
      "",
      "",
    })
  end)

  it("process input", function()
    local input = { "This is a line", "This is another line", "", "" }
    local p = process.new {
      cmd = { "tee", "output" },
      cwd = "./tests",
    }

    p:spawn()

    print("Sending: ", vim.inspect(table.concat(input, "\n")))
    p:send(table.concat(input, "\n"))

    p:close_stdin()
    p:wait(1000)

    local lines = {}
    local result = process
      .new({
        cmd = { "cat", "output" },
        cwd = "./tests",

        on_line = function(_, line)
          table.insert(lines, line)
        end,
      })
      :spawn_blocking(1000)

    assert(result)
    assert.are.same(result.stdout, input)
    assert.are.same(lines, input)
  end)
  it("basic command trim", function()
    local result =
      process.new({ cmd = { "cat", "process_test" }, cwd = "./tests" }):spawn_blocking(1000):trim()
    assert(result)
    assert.are.same(result.stdout, {
      "This is a test file",
      "It is intended to be read by cat and returned to neovim using the process api",
    })
  end)
end)
