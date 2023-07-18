require("plenary.async").tests.add_to_env()
local util = require("tests.util.util")
local eq = assert.are.same

local process = require("neogit.process")

describe("process execution", function()
  it("basic command", function()
    local result =
      process.new({ cmd = { "cat", "process_test" }, cwd = util.get_fixtures_dir() }):spawn_blocking(1000)
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
  it("can cat a file", function()
    local result =
      process.new({ cmd = { "cat", "a.txt" }, cwd = util.get_fixtures_dir() }):spawn_blocking(1000)

    assert(result)
    assert.are.same(result.stdout, {
      "Lorem ipsum dolor sit amet, officia excepteur ex fugiat reprehenderit enim labore culpa sint ad nisi Lorem pariatur mollit ex esse exercitation amet.",
      "Nisi anim cupidatat excepteur officia.",
      "Reprehenderit nostrud nostrud ipsum Lorem est aliquip amet voluptate voluptate dolor minim nulla est proident.",
      "Nostrud officia pariatur ut officia.",
      "Sit irure elit esse ea nulla sunt ex occaecat reprehenderit commodo officia dolor Lorem duis laboris cupidatat officia voluptate.",
      "",
      "Culpa proident adipisicing id nulla nisi laboris ex in Lorem sunt duis officia eiusmod.",
      "Aliqua reprehenderit commodo ex non excepteur duis sunt velit enim.",
      "Voluptate laboris sint cupidatat ullamco ut ea consectetur et est culpa et culpa duis.",
      "",
    })
  end)

  it("process input", function()
    vim.fn.mkdir("tmp/", "p")
    local p = process
      .new({
        cmd = { "rm", "tmp/output" },
      })
      :spawn_blocking()
    local input = { "This is a line", "This is another line", "", "" }
    local p = process.new {
      cmd = { "tee", "tmp/output" },
    }

    p:spawn()

    local expecting = {}
    for _, v in ipairs(input) do
      expecting[#expecting + 1] = v
    end

    print("Sending: ", vim.inspect(table.concat(expecting, "\n")))
    p:send(table.concat(input, "\n"))
    p:send("\04")

    p:close_stdin()
    p:wait()

    print("Output:", vim.fn.system("cat tmp/output"))

    local lines = {}
    local result = process
      .new({
        cmd = { "cat", "tmp/output" },
      })
      :spawn_blocking(1000)

    assert(result)
    print("Lines: ", vim.inspect(lines))
    assert.are.same(result.stdout, input)
  end)
  it("basic command trim", function()
    local result = process
      .new({ cmd = { "cat", "process_test" }, cwd = util.get_fixtures_dir() })
      :spawn_blocking(1000)
      :trim()
    assert(result)
    assert.are.same(result.stdout, {
      "This is a test file",
      "It is intended to be read by cat and returned to neovim using the process api",
    })
  end)
end)
