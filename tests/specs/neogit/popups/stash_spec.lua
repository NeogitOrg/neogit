local eq = assert.are.same
local config = require("neogit.config")
local git = require("neogit.lib.git")
local stash_actions = require("neogit.popups.stash.actions")
local input_mock = require("tests.mocks.input")

describe("stash popup actions", function()
  local original_stash_all, original_stash_index, original_stash_keep_index, original_push
  local original_files_all, original_fuzzy_finder, original_prompt_stash_message

  local popup_mock = {
    get_arguments = function()
      return {}
    end,
  }

  before_each(function()
    original_stash_all = git.stash.stash_all
    original_stash_index = git.stash.stash_index
    original_stash_keep_index = git.stash.stash_keep_index
    original_push = git.stash.push
    original_files_all = git.files.all
    original_fuzzy_finder = require("neogit.buffers.fuzzy_finder").new
    original_prompt_stash_message = config.values.prompt_stash_message

    input_mock.values = {}
  end)

  after_each(function()
    git.stash.stash_all = original_stash_all
    git.stash.stash_index = original_stash_index
    git.stash.stash_keep_index = original_stash_keep_index
    git.stash.push = original_push
    git.files.all = original_files_all
    require("neogit.buffers.fuzzy_finder").new = original_fuzzy_finder
    config.values.prompt_stash_message = original_prompt_stash_message
  end)

  it("asks for a message and passes it to the stash", function()
    config.values.prompt_stash_message = true
    input_mock.values = { "my stash" }

    local args, message
    git.stash.stash_all = function(a, msg)
      args = a
      message = msg
    end

    stash_actions.both(popup_mock)

    eq({}, args)
    eq("my stash", message)
  end)

  it("does not ask for a message when the prompt is disabled", function()
    config.values.prompt_stash_message = false
    input_mock.values = { "my stash" }

    local message = "not called"
    git.stash.stash_all = function(_, msg)
      message = msg
    end

    stash_actions.both(popup_mock)

    eq(nil, message)
    eq(1, #input_mock.values, "the prompt should not have been shown")
  end)

  it("stashes without a message when the input is aborted", function()
    config.values.prompt_stash_message = true
    input_mock.values = {}

    local message = "not called"
    git.stash.stash_index = function(msg)
      message = msg
    end

    stash_actions.index()

    eq(nil, message)
  end)

  it("stashes without a message when the input is empty", function()
    config.values.prompt_stash_message = true
    input_mock.values = { "" }

    local message = "not called"
    git.stash.stash_index = function(msg)
      message = msg
    end

    stash_actions.index()

    eq(nil, message)
  end)

  it("passes the message when keeping the index", function()
    config.values.prompt_stash_message = true
    input_mock.values = { "keep index stash" }

    local message
    git.stash.stash_keep_index = function(msg)
      message = msg
    end

    stash_actions.keep_index()

    eq("keep index stash", message)
  end)

  it("passes the message when pushing files to the stash", function()
    config.values.prompt_stash_message = true
    input_mock.values = { "pushed stash" }

    git.files.all = function()
      return { "foo.txt" }
    end

    require("neogit.buffers.fuzzy_finder").new = function()
      return {
        open_async = function()
          return { "foo.txt" }
        end,
      }
    end

    local files, message
    git.stash.push = function(_, f, msg)
      files = f
      message = msg
    end

    stash_actions.push(popup_mock)

    eq({ "foo.txt" }, files)
    eq("pushed stash", message)
  end)
end)
