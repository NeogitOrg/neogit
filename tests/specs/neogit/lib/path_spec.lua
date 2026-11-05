local eq = assert.are.same
local Path = require("neogit.lib.path")

describe("lib.path", function()
  describe("Path:absolute", function()
    it("resolves a relative path against the given base", function()
      eq("/base/sub/file", Path:new("sub/file"):absolute("/base"))
    end)

    it("keeps an absolute path unchanged", function()
      eq("/other/file", Path:new("/other/file"):absolute("/base"))
    end)

    it("accepts a Path as the base", function()
      eq("/base/sub/file", Path:new("sub/file"):absolute(Path:new("/base")))
    end)

    it("strips a trailing separator", function()
      eq("/base", Path:new("/base/"):absolute("/other"))
    end)
  end)
end)
