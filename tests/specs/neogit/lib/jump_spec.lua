local subject = require("neogit.lib.jump")

describe("lib.jump.translate_hunk_location", function()
  local hunk

  before_each(function()
    hunk = {
      disk_from = 10,
      index_from = 20,
      lines = {
        " context",
        "+added",
        "-removed",
        " trailing",
      },
    }
  end)

  it("returns nil when hunk is missing or offset is invalid", function()
    assert.is_nil(subject.translate_hunk_location(nil, 1))
    assert.is_nil(subject.translate_hunk_location({ disk_from = 1, index_from = 1, lines = {} }, 0))
    assert.is_nil(subject.translate_hunk_location(hunk, #hunk.lines + 1))
  end)

  it("adjusts old line numbers when additions are present", function()
    local location = subject.translate_hunk_location(hunk, 2)

    assert.are.same({
      old = 10,
      new = 21,
      line = "+added",
    }, location)
  end)

  it("adjusts new line numbers when deletions are present", function()
    local location = subject.translate_hunk_location(hunk, 3)

    assert.are.same({
      old = 11,
      new = 21,
      line = "-removed",
    }, location)
  end)
end)
