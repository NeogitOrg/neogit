local eq = assert.are.same

local stubbed = { "codediff.core.git", "codediff.ui.view", "codediff.core.path" }

describe("codediff integration", function()
  local codediff = require("neogit.integrations.codediff")
  local originals, created

  before_each(function()
    originals = {}
    for _, name in ipairs(stubbed) do
      originals[name] = package.loaded[name]
    end

    created = nil
    package.loaded["codediff.core.git"] = {
      get_status = function(_, callback)
        callback(nil, { unstaged = {}, staged = {} })
      end,
      get_diff_revisions = function() end,
      resolve_revision = function() end,
      get_relative_path = function() end,
    }
    package.loaded["codediff.ui.view"] = {
      create = function(session_config)
        created = session_config
      end,
    }
    package.loaded["codediff.core.path"] = {
      empty = function()
        return {}
      end,
      make_ref = function() end,
    }
  end)

  after_each(function()
    for _, name in ipairs(stubbed) do
      package.loaded[name] = originals[name]
    end
  end)

  local function open(section_name, item_name)
    codediff.open(section_name, item_name, { only = true })
    vim.wait(1000, function()
      return created ~= nil
    end)
    assert.is_not_nil(created, "codediff view should be created")
    return created
  end

  describe("untracked section", function()
    it("opens the status explorer focused on the file", function()
      local session_config = open("untracked", "new_file.txt")

      eq("explorer", session_config.panel.name)
      eq("new_file.txt", session_config.panel.data.focus_file)
    end)

    it("opens the status explorer from the section heading", function()
      local session_config = open("untracked", nil)

      eq("explorer", session_config.panel.name)
      eq(nil, session_config.panel.data.focus_file)
    end)
  end)
end)
