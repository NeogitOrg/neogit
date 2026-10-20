local subject = require("neogit.lib.util")

describe("lib.util", function()
  describe("#str_first_char", function()
    it("returns the first ASCII character", function()
      assert.are.same("s", subject.str_first_char("seconds"))
    end)

    it("returns the first UTF-8 character", function()
      assert.are.same("秒", subject.str_first_char("秒前"))
    end)

    describe("#remove_ansi_escape_codes", function()
      it("strips SGR color sequences", function()
        assert.are.same("red", subject.remove_ansi_escape_codes("\27[31mred\27[0m"))
      end)

      it("strips SGR reset without parameters", function()
        assert.are.same("text", subject.remove_ansi_escape_codes("\27[mtext"))
      end)

      it("strips cursor movement and erase sequences", function()
        assert.are.same("", subject.remove_ansi_escape_codes("\27[2K\27[1A"))
      end)

      it("does not corrupt UTF-8 Romanian characters", function()
        assert.are.same("țășîâȚĂȘÎÂ", subject.remove_ansi_escape_codes("țășîâȚĂȘÎÂ"))
      end)

      it("does not corrupt the sequence 'ți'", function()
        assert.are.same("națiune", subject.remove_ansi_escape_codes("națiune"))
        assert.are.same("ți", subject.remove_ansi_escape_codes("ți"))
      end)

      it("does not corrupt UTF-8 when ANSI sequences are present", function()
        assert.are.same(
          "națiune colorată",
          subject.remove_ansi_escape_codes("\27[31mnațiune\27[0m \27[32mcolorată\27[0m")
        )
      end)

      it("does not corrupt other UTF-8 scripts", function()
        assert.are.same("日本語テキст", subject.remove_ansi_escape_codes("日本語テキст"))
        assert.are.same("🎉 emoji", subject.remove_ansi_escape_codes("🎉 emoji"))
      end)
    end)
  end)
end)
