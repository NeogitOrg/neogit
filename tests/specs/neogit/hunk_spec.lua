local eq = assert.are.same
-- IMPORTANT: Verify this require path matches the actual location in Neogit's source
local Hunk = require("neogit.buffers.common").Hunk

describe("Hunk Component", function()
  it("correctly highlights standard context lines starting with a minus", function()
    local props = {
      header = "@@ -1,3 +1,4 @@",
      content = {
        "  foo:",
        " -- tricky context with minus",
        " +- tricky context with plus",
        "- deleted line",
        "+ added line",
      },
      hunk = {
        line = "@@ -1,3 +1,4 @@",
      },
    }

    local result = Hunk(props)
    local lines = result.children[2].children

    -- "  foo:" -> Pure context
    eq("NeogitDiffContext", lines[1].options.line_hl)

    -- " -- tricky context with minus" -> SHOULD BE CONTEXT NOW (Fixes the bug)
    eq("NeogitDiffContext", lines[2].options.line_hl)

    -- " +- tricky context with plus" -> SHOULD BE CONTEXT
    eq("NeogitDiffContext", lines[3].options.line_hl)

    -- "- deleted line" -> Actual deletion
    eq("NeogitDiffDelete", lines[4].options.line_hl)

    -- "+ added line" -> Actual addition
    eq("NeogitDiffAdd", lines[5].options.line_hl)
  end)

  it("correctly highlights combined diff lines (merge conflicts)", function()
    local props = {
      header = "@@@ -1,3 -1,3 +1,4 @@@",
      content = {
        "  foo:",
        " -- deleted in both parents",
        " ++ added in both parents",
        " +- added parent 1, deleted parent 2",
      },
      hunk = {
        line = "@@@ -1,3 -1,3 +1,4 @@@",
      },
    }

    local result = Hunk(props)
    local lines = result.children[2].children

    -- "  foo:" (Context, 2 prefix spaces)
    eq("NeogitDiffContext", lines[1].options.line_hl)

    -- " -- deleted in both parents"
    eq("NeogitDiffDelete", lines[2].options.line_hl)

    -- " ++ added in both parents"
    eq("NeogitDiffAdd", lines[3].options.line_hl)

    -- " +- added parent 1, deleted parent 2"
    eq("NeogitDiffAdd", lines[4].options.line_hl)
  end)
end)
