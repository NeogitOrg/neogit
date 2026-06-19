local subject = require("neogit.lib.util")

describe("lib.util", function()
  describe("#str_first_char", function()
    it("returns the first ASCII character", function()
      assert.are.same("s", subject.str_first_char("seconds"))
    end)

    it("returns the first UTF-8 character", function()
      assert.are.same("秒", subject.str_first_char("秒前"))
    end)
  end)
end)
