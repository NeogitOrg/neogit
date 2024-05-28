local subject = require("neogit.lib.record")

describe("lib.record", function()
  describe("#encode", function()
    it("turns lua table into delimited string (log)", function()
      assert.are.same("foo%x1Dbar%x1E", subject.encode({ foo = "bar" }, "log"))
    end)

    it("turns lua table into delimited string (for-each-ref)", function()
      assert.are.same("foo%1Dbar%1E", subject.encode({ foo = "bar" }, "ref"))
    end)
  end)

  describe("#decode", function()
    it("can decode multiple delimited objects", function()
      local input = {
        "baz\29boo\31foo\29bar\30",
        "biz\29bip\31bop\29bip\30",
      }

      assert.are.same({ { foo = "bar", baz = "boo" }, { biz = "bip", bop = "bip" } }, subject.decode(input))
    end)

    it("can decode git log output", function()
      local input = {
        "tree\29d7636d8291992cd11f514b4a5e7fcd3148ed4cf4\31subject\29Pull encode logic into json module\31oid\29ce412df53d565c8c496cfcc806fe11582b6a9b10\31encoding\29\31rel_date\29Five minutes ago\31abbreviated_parent\29f3fe8284\31abbreviated_commit\29ce412df5\31abbreviated_tree\29d7636d82\31author_name\29Cameron\31parent\29f3fe8284052c90d050fb1557eb8f51e4224a16d5\31author_date\29Mon, 1 Jan 2024 21:58:45 +0100\31body\29\31ref_name\29HEAD -> fix/json-parsing, origin/fix/json-parsing\31committer_name\29Cameron\31committer_email\29Alleyria@gmail.com\31sanitized_subject_line\29Pull-encode-logic-into-json-module\31commit_notes\29\31committer_date\29Mon, 1 Jan 2024 21:58:45 +0100\31author_email\29Alleyria@gmail.com\30",
      }

      local parsed = subject.decode(input)

      assert.are.same({
        {
          abbreviated_commit = "ce412df5",
          abbreviated_parent = "f3fe8284",
          abbreviated_tree = "d7636d82",
          author_date = "Mon, 1 Jan 2024 21:58:45 +0100",
          author_email = "Alleyria@gmail.com",
          author_name = "Cameron",
          body = "",
          commit_notes = "",
          committer_date = "Mon, 1 Jan 2024 21:58:45 +0100",
          committer_email = "Alleyria@gmail.com",
          committer_name = "Cameron",
          encoding = "",
          oid = "ce412df53d565c8c496cfcc806fe11582b6a9b10",
          parent = "f3fe8284052c90d050fb1557eb8f51e4224a16d5",
          ref_name = "HEAD -> fix/json-parsing, origin/fix/json-parsing",
          rel_date = "Five minutes ago",
          sanitized_subject_line = "Pull-encode-logic-into-json-module",
          subject = "Pull encode logic into json module",
          tree = "d7636d8291992cd11f514b4a5e7fcd3148ed4cf4",
        },
      }, parsed)
    end)
  end)
end)
