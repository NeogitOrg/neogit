local subject = require("neogit.lib.json")

describe("lib.json", function()
  describe("#encode", function()
    it("turns a lua table into json with a trailing comma", function()
      assert.are.same('{"foo":"bar","null":null},', subject.encode { foo = "bar" })
    end)
  end)

  describe("#decode", function()
    it("can decode multiple json objects", function()
      local input = {
        '{"foo":"bar"},',
        '{"baz":"daz"},',
      }

      assert.are.same({ { foo = "bar" }, { baz = "daz" } }, subject.decode(input))
    end)

    it("can escape specified fields", function()
      local input = {
        [[{"foo":""invalid"","bar":"valid"},]],
      }

      assert.are.same(
        { { foo = '"invalid"', bar = "valid" } },
        subject.decode(input, { escaped_fields = { "foo" } })
      )
    end)

    it("can decode git log output", function()
      local input = {
        '{"tree":"d7636d8291992cd11f514b4a5e7fcd3148ed4cf4","subject":"Pull encode logic into json module","oid":"ce412df53d565c8c496cfcc806fe11582b6a9b10","encoding":"","rel_date":"5 minutes ago","abbreviated_parent":"33fe8284","abbreviated_commit":"ce412df5","abbreviated_tree":"d7636d82","author_name":"Cameron","parent":"33fe8284052c90d050fb1557eb8f51e4224a16d5","author_date":"Mon, 1 Jan 2024 21:58:45 +0100","body":"","ref_name":"HEAD -> fix/json-parsing, origin/fix/json-parsing","committer_name":"Cameron","committer_email":"Alleyria@gmail.com","sanitized_subject_line":"Pull-encode-logic-into-json-module","commit_notes":"","committer_date":"Mon, 1 Jan 2024 21:58:45 +0100","author_email":"Alleyria@gmail.com"},',
      }

      local parsed =
        subject.decode(input, { escaped_fields = { "body", "author_name", "committer_name", "subject" } })

      assert.are.same({
        {
          abbreviated_commit = "ce412df5",
          abbreviated_parent = "33fe8284",
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
          parent = "33fe8284052c90d050fb1557eb8f51e4224a16d5",
          ref_name = "HEAD -> fix/json-parsing, origin/fix/json-parsing",
          rel_date = "5 minutes ago",
          sanitized_subject_line = "Pull-encode-logic-into-json-module",
          subject = "Pull encode logic into json module",
          tree = "d7636d8291992cd11f514b4a5e7fcd3148ed4cf4",
        },
      }, parsed)
    end)
  end)
end)
