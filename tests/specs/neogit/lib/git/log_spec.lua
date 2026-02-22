local subject = require("neogit.lib.git.log")

describe("lib.git.log.parse", function()
  it("parses commit with message and diff", function()
    local commit = {
      "commit a7cde0fe1356fe06a2a1f14f421512a6c4cc5acc",
      "Author:     Cameron <Alleyria@gmail.com>",
      "AuthorDate: Fri Sep 29 17:00:15 2023 +0200",
      "Commit:     Cameron <Alleyria@gmail.com>",
      "CommitDate: Fri Sep 29 17:00:15 2023 +0200",
      "",
      "    Fixes finding the right section",
      "",
      "diff --git a/lua/neogit/status.lua b/lua/neogit/status.lua",
      "index 020bb25b..e17bf025 100644",
      "--- a/lua/neogit/status.lua",
      "+++ b/lua/neogit/status.lua",
      "@@ -692,33 +692,28 @@ end",
      " ---@param first_line number",
      " ---@param last_line number",
      " ---@param partial boolean",
      "----@return SelectedHunk[],string[]",
      "+---@return SelectedHunk[]",
      " function M.get_item_hunks(item, first_line, last_line, partial)",
      "   if item.folded or item.hunks == nil then",
      "-    return {}, {}",
      "+    return {}",
      "   end",
      " ",
      "   local hunks = {}",
      "-  local lines = {}",
      " ",
      "   for _, h in ipairs(item.hunks) do",
      "-    -- Transform to be relative to the current item/file",
      "-    local first_line = first_line - item.first",
      "-    local last_line = last_line - item.first",
      "-",
      "-    if h.diff_from <= last_line and h.diff_to >= first_line then",
      "-      -- Relative to the hunk",
      "+    if h.first <= last_line and h.last >= first_line then",
      "       local from, to",
      "+",
      "       if partial then",
      "-        from = h.diff_from + math.max(first_line - h.diff_from, 0)",
      "-        to = math.min(last_line, h.diff_to)",
      "+        local length = last_line - first_line",
      "+        from = h.diff_from + math.max((first_line - item.first) - h.diff_from, 0)",
      "+        to = from + length",
      "       else",
      "         from = h.diff_from + 1",
      "         to = h.diff_to",
      "       end",
      " ",
      "       local hunk_lines = {}",
      "-",
      "       for i = from, to do",
      "         table.insert(hunk_lines, item.diff.lines[i])",
      "       end",
      "@@ -734,14 +729,10 @@ function M.get_item_hunks(item, first_line, last_line, partial)",
      "       setmetatable(o, o)",
      " ",
      "       table.insert(hunks, o)",
      "-",
      "-      for i = from, to do",
      "-        table.insert(lines, item.diff.lines[i + h.diff_from])",
      "-      end",
      "     end",
      "   end",
      " ",
      "-  return hunks, lines",
      "+  return hunks",
      " end",
      " ",
      " ---@param selection Selection",
      "",
    }

    local expected = {
      author_date = "Fri Sep 29 17:00:15 2023 +0200",
      author_email = "Alleyria@gmail.com",
      author_name = "Cameron",
      committer_date = "Fri Sep 29 17:00:15 2023 +0200",
      committer_email = "Alleyria@gmail.com",
      committer_name = "Cameron",
      description = { "Fixes finding the right section" },
      diffs = {
        {
          file = "lua/neogit/status.lua",
          hunks = {
            {
              diff_from = 1,
              diff_to = 41,
              disk_from = 692,
              disk_len = 28,
              hash = "29ceb3dbfe9397ecb886d9ef8ac138af0ea3b46125318c94852a7289dd5be6b8",
              index_from = 692,
              index_len = 33,
              length = 40,
              file = "lua/neogit/status.lua",
              line = "@@ -692,33 +692,28 @@ end",
              lines = {
                " ---@param first_line number",
                " ---@param last_line number",
                " ---@param partial boolean",
                "----@return SelectedHunk[],string[]",
                "+---@return SelectedHunk[]",
                " function M.get_item_hunks(item, first_line, last_line, partial)",
                "   if item.folded or item.hunks == nil then",
                "-    return {}, {}",
                "+    return {}",
                "   end",
                " ",
                "   local hunks = {}",
                "-  local lines = {}",
                " ",
                "   for _, h in ipairs(item.hunks) do",
                "-    -- Transform to be relative to the current item/file",
                "-    local first_line = first_line - item.first",
                "-    local last_line = last_line - item.first",
                "-",
                "-    if h.diff_from <= last_line and h.diff_to >= first_line then",
                "-      -- Relative to the hunk",
                "+    if h.first <= last_line and h.last >= first_line then",
                "       local from, to",
                "+",
                "       if partial then",
                "-        from = h.diff_from + math.max(first_line - h.diff_from, 0)",
                "-        to = math.min(last_line, h.diff_to)",
                "+        local length = last_line - first_line",
                "+        from = h.diff_from + math.max((first_line - item.first) - h.diff_from, 0)",
                "+        to = from + length",
                "       else",
                "         from = h.diff_from + 1",
                "         to = h.diff_to",
                "       end",
                " ",
                "       local hunk_lines = {}",
                "-",
                "       for i = from, to do",
                "         table.insert(hunk_lines, item.diff.lines[i])",
                "       end",
              },
            },
            {
              diff_from = 42,
              diff_to = 57,
              disk_from = 729,
              disk_len = 10,
              hash = "07d81a3a449c3535229b434007b918e33be3fe02edc60be16209f5b4a05becee",
              index_from = 734,
              index_len = 14,
              length = 15,
              file = "lua/neogit/status.lua",
              line = "@@ -734,14 +729,10 @@ function M.get_item_hunks(item, first_line, last_line, partial)",
              lines = {
                "       setmetatable(o, o)",
                " ",
                "       table.insert(hunks, o)",
                "-",
                "-      for i = from, to do",
                "-        table.insert(lines, item.diff.lines[i + h.diff_from])",
                "-      end",
                "     end",
                "   end",
                " ",
                "-  return hunks, lines",
                "+  return hunks",
                " end",
                " ",
                " ---@param selection Selection",
              },
            },
          },
          info = {},
          kind = "modified",
          lines = {
            "@@ -692,33 +692,28 @@ end",
            " ---@param first_line number",
            " ---@param last_line number",
            " ---@param partial boolean",
            "----@return SelectedHunk[],string[]",
            "+---@return SelectedHunk[]",
            " function M.get_item_hunks(item, first_line, last_line, partial)",
            "   if item.folded or item.hunks == nil then",
            "-    return {}, {}",
            "+    return {}",
            "   end",
            " ",
            "   local hunks = {}",
            "-  local lines = {}",
            " ",
            "   for _, h in ipairs(item.hunks) do",
            "-    -- Transform to be relative to the current item/file",
            "-    local first_line = first_line - item.first",
            "-    local last_line = last_line - item.first",
            "-",
            "-    if h.diff_from <= last_line and h.diff_to >= first_line then",
            "-      -- Relative to the hunk",
            "+    if h.first <= last_line and h.last >= first_line then",
            "       local from, to",
            "+",
            "       if partial then",
            "-        from = h.diff_from + math.max(first_line - h.diff_from, 0)",
            "-        to = math.min(last_line, h.diff_to)",
            "+        local length = last_line - first_line",
            "+        from = h.diff_from + math.max((first_line - item.first) - h.diff_from, 0)",
            "+        to = from + length",
            "       else",
            "         from = h.diff_from + 1",
            "         to = h.diff_to",
            "       end",
            " ",
            "       local hunk_lines = {}",
            "-",
            "       for i = from, to do",
            "         table.insert(hunk_lines, item.diff.lines[i])",
            "       end",
            "@@ -734,14 +729,10 @@ function M.get_item_hunks(item, first_line, last_line, partial)",
            "       setmetatable(o, o)",
            " ",
            "       table.insert(hunks, o)",
            "-",
            "-      for i = from, to do",
            "-        table.insert(lines, item.diff.lines[i + h.diff_from])",
            "-      end",
            "     end",
            "   end",
            " ",
            "-  return hunks, lines",
            "+  return hunks",
            " end",
            " ",
            " ---@param selection Selection",
          },
          stats = {
            additions = 0,
            deletions = 0,
          },
        },
      },
      oid = "a7cde0fe1356fe06a2a1f14f421512a6c4cc5acc",
    }

    assert.are.same(subject.parse(commit)[1], expected)
  end)

  it("parses commit without message", function()
    local commit = {
      "commit 1216bd2385d37b147775cfa6880fc90984e6e2f0",
      "Author:     Cameron <Alleyria@gmail.com>",
      "AuthorDate: Mon Oct 2 15:40:03 2023 +0200",
      "Commit:     Cameron <Alleyria@gmail.com>",
      "CommitDate: Mon Oct 2 15:40:03 2023 +0200",
      " ",
      "diff --git a/LICENSE b/LICENSE",
      "index 09c1b7ad..a70e7709 100644",
      "--- a/LICENSE",
      "+++ b/LICENSE",
      "@@ -1,7 +1,9 @@",
      " MIT License",
      " ",
      "+hello",
      " Copyright (c) 2020 TimUntersberger",
      " ",
      "+world",
      " Permission is hereby granted, free of charge, to any person obtaining a copy",
      ' of this software and associated documentation files (the "Software"), to deal',
      " in the Software without restriction, including without limitation the rights",
      "",
    }

    local expected = {
      oid = "1216bd2385d37b147775cfa6880fc90984e6e2f0",
      author_date = "Mon Oct 2 15:40:03 2023 +0200",
      author_email = "Alleyria@gmail.com",
      author_name = "Cameron",
      committer_date = "Mon Oct 2 15:40:03 2023 +0200",
      committer_email = "Alleyria@gmail.com",
      committer_name = "Cameron",
      description = {},
      diffs = {
        {
          file = "LICENSE",
          hunks = {
            {
              diff_from = 1,
              diff_to = 10,
              disk_from = 1,
              disk_len = 9,
              hash = "092d9a04537ba4a006a439721537adeeb69d1d692f1d763e6d859d01a317e92e",
              index_from = 1,
              index_len = 7,
              length = 9,
              line = "@@ -1,7 +1,9 @@",
              file = "LICENSE",
              lines = {
                " MIT License",
                " ",
                "+hello",
                " Copyright (c) 2020 TimUntersberger",
                " ",
                "+world",
                " Permission is hereby granted, free of charge, to any person obtaining a copy",
                ' of this software and associated documentation files (the "Software"), to deal',
                " in the Software without restriction, including without limitation the rights",
              },
            },
          },
          info = {},
          kind = "modified",
          lines = {
            "@@ -1,7 +1,9 @@",
            " MIT License",
            " ",
            "+hello",
            " Copyright (c) 2020 TimUntersberger",
            " ",
            "+world",
            " Permission is hereby granted, free of charge, to any person obtaining a copy",
            ' of this software and associated documentation files (the "Software"), to deal',
            " in the Software without restriction, including without limitation the rights",
          },
          stats = {
            additions = 0,
            deletions = 0,
          },
        },
      },
    }

    assert.are.same(subject.parse(commit)[1], expected)
  end)

  it("lib.git.log.branch_info extracts local branch name", function()
    local remotes = { "origin" }
    assert.are.same(
      { tags = {}, locals = { main = true }, remotes = {} },
      subject.branch_info("main", remotes)
    )
    assert.are.same({
      locals = { main = true, develop = true },
      remotes = {},
      tags = {},
    }, subject.branch_info("main, develop", remotes))
  end)

  it("lib.git.log.branch_info extracts head", function()
    local remotes = { "origin" }
    assert.are.same(
      { head = "main", locals = { main = true }, remotes = {}, tags = {} },
      subject.branch_info("HEAD -> main", remotes)
    )
    assert.are.same({
      head = "develop",
      locals = { main = true, develop = true },
      remotes = {},
      tags = {},
    }, subject.branch_info("main, HEAD -> develop", remotes))
    assert.are.same({
      head = "foo",
      locals = { foo = true, develop = true },
      remotes = {
        main = { "origin" },
        foo = { "origin" },
      },
      tags = {},
    }, subject.branch_info(
      "HEAD -> foo, origin/HEAD, origin/main, foo, origin/foo, develop",
      { "origin" }
    ))
  end)

  it("lib.git.log.branch_info extracts local & remote branch names (tracked)", function()
    local remotes = { "origin" }
    assert.are.same(
      { tags = {}, locals = { main = true }, remotes = { main = remotes } },
      subject.branch_info("main, origin/main", remotes)
    )
    assert.are.same({
      locals = { main = true, develop = true },
      remotes = {
        main = remotes,
        develop = remotes,
      },
      tags = {},
    }, subject.branch_info("main, develop, origin/main, origin/develop", remotes))
    assert.are.same({
      locals = { main = true },
      remotes = {
        main = remotes,
        develop = remotes,
      },
      tags = {},
    }, subject.branch_info("origin/main, main, origin/develop", remotes))
    assert.are.same({
      tags = {},
      locals = { main = true, develop = true, foo = true },
      remotes = {
        main = remotes,
        develop = remotes,
      },
    }, subject.branch_info("main, origin/main, origin/develop, develop, foo", remotes))
  end)

  it("lib.git.log.branch_info can deal with multiple remotes", function()
    local remotes = { "origin", "fork" }
    assert.are.same({
      locals = { main = true },
      remotes = {
        main = { "origin", "fork" },
      },
      tags = {},
    }, subject.branch_info("origin/main, main, fork/main", remotes))
    assert.are.same({
      locals = { develop = true, foo = true },
      remotes = {
        main = { "origin" },
        develop = { "origin", "fork" },
      },
      tags = {},
    }, subject.branch_info("origin/main, develop, origin/develop, fork/develop, foo", remotes))
  end)

  it("lib.git.log.branch_info can deal with slashes in branch names", function()
    local remotes = { "origin" }
    assert.are.same({
      locals = { ["feature/xyz"] = true, ["foo/bar/baz"] = true },
      remotes = {
        ["feature/xyz"] = { "origin" },
      },
      tags = {},
    }, subject.branch_info("feature/xyz, foo/bar/baz, origin/feature/xyz", remotes))
  end)

  it("lib.git.log.branch_info ignores HEAD references", function()
    local remotes = { "origin", "fork" }
    assert.are.same({
      remotes = { main = { "origin", "fork" } },
      locals = { develop = true },
      tags = {},
    }, subject.branch_info("origin/main, fork/main, develop, origin/HEAD, fork/HEAD", remotes))
  end)

  it("lib.git.log.branch_info parses tags", function()
    local remotes = { "origin" }
    assert.are.same(
      { locals = {}, remotes = {}, tags = { "0.1.0" } },
      subject.branch_info("tag: 0.1.0", remotes)
    )
    assert.are.same({
      locals = {},
      remotes = {},
      tags = { "0.5.7", "foo-bar" },
    }, subject.branch_info("tag: 0.5.7, tag: foo-bar", remotes))
  end)
end)
