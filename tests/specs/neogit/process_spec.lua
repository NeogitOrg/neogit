require("plenary.async").tests.add_to_env()
local util = require("tests.util.util")

local process = require("neogit.process")

describe("process execution", function()
  it("basic command", function()
    local result =
      process.new({ cmd = { "cat", "process_test" }, cwd = util.get_fixtures_dir() }):spawn_blocking(1)
    assert(result)
    assert.are.same({
      "This is a test file",
      "",
      "",
      "It is intended to be read by cat and returned to neovim using the process api",
      "",
      "",
    }, result.stdout)
  end)

  it("can cat a file", function()
    local result = process.new({ cmd = { "cat", "a.txt" }, cwd = util.get_fixtures_dir() }):spawn_blocking(1)

    assert(result)
    assert.are.same({
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
    }, result.stdout)
  end)

  it("process input", function()
    local tmp_dir = util.create_temp_dir()
    local input = { "This is a line", "This is another line", "", "" }
    local p = process.new { cmd = { "tee", tmp_dir .. "/output" } }

    p:spawn()
    p:send(table.concat(input, "\n"))
    p:send("\04")
    p:close_stdin()
    p:wait()

    local result = process.new({ cmd = { "cat", tmp_dir .. "/output" } }):spawn_blocking(1)
    assert(result)
    assert.are.same(input, result.stdout)
  end)

  it("basic command trim", function()
    local result =
      process.new({ cmd = { "cat", "process_test" }, cwd = util.get_fixtures_dir() }):spawn_blocking(1)

    assert(result)
    assert.are.same({
      "This is a test file",
      "It is intended to be read by cat and returned to neovim using the process api",
    }, result:trim().stdout)
  end)
end)
