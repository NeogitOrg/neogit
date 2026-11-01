local eq = assert.are.same
local cli = require("neogit.lib.git.cli")
local stash = require("neogit.lib.git.stash")

describe("git.stash", function()
  local builders, original_stash

  ---@return table builder fake cli builder, recording every call
  local function new_fake_builder()
    local calls = {}
    local builder = { calls = calls }

    setmetatable(builder, {
      __index = function(t, key)
        return function(...)
          table.insert(calls, { key, ... })
          return t
        end
      end,
    })

    builder.call = function()
      table.insert(calls, { "call" })
      return {
        success = function()
          return true
        end,
      }
    end

    return builder
  end

  ---Checks if the builder was called with the given key and value
  local function called_with(builder, key, value)
    for _, call in ipairs(builder.calls) do
      if call[1] == key and call[2] == value then
        return true
      end
    end

    return false
  end

  before_each(function()
    builders = {}
    original_stash = rawget(cli, "stash")

    rawset(
      cli,
      "stash",
      setmetatable({}, {
        __index = function(t, key)
          local builder = new_fake_builder()
          builders[key] = builder
          rawset(t, key, builder)
          return builder
        end,
      })
    )
  end)

  after_each(function()
    rawset(cli, "stash", original_stash)
  end)

  it("passes the message to the stash command", function()
    stash.stash_all({}, "my message")

    eq(true, called_with(builders.push, "message", "my message"))
  end)

  it("does not pass a message when none was given", function()
    stash.stash_all {}

    eq(false, called_with(builders.push, "message", "my message"))
  end)

  it("passes the message when stashing the index", function()
    stash.stash_index("my message")

    eq(true, called_with(builders.staged, "message", "my message"))
  end)

  it("passes the message when keeping the index", function()
    stash.stash_keep_index("my message")

    eq(true, called_with(builders.keep_index, "message", "my message"))
  end)

  it("passes the message when pushing files to the stash", function()
    stash.push({}, { "foo.txt" }, "my message")

    eq(true, called_with(builders.push, "message", "my message"))
  end)
end)
