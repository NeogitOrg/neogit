local eq = assert.are.same
local status = require("neogit.status")
local harness = require("tests.util.git_harness")
local system = require("tests.util.util").system
local _ = require("tests.mocks.input")
local in_prepared_repo = harness.in_prepared_repo
local get_git_status = harness.get_git_status
local get_git_diff = harness.get_git_diff

local function act(normal_cmd)
  print("Feeding keys: ", normal_cmd)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(normal_cmd, true, true, true))
  vim.fn.feedkeys("", "x") -- flush typeahead
  status.wait_on_current_operation()
end

local function find(text)
  for index, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, true)) do
    if line:match(text) then
      vim.api.nvim_win_set_cursor(0, { index, 0 })
      return unpack { line, index }
    end
  end
end

describe("status buffer", function()
  describe("staging files - s", function()
    it(
      "can stage an untracked file under the cursor",
      in_prepared_repo(function()
        find("untracked%.txt")
        act("s")
        eq("A  untracked.txt\n", get_git_status("untracked.txt"))
      end)
    )

    it(
      "can stage a tracked file under the cursor",
      in_prepared_repo(function()
        find("Modified a%.txt")
        eq(" M a.txt\n", get_git_status("a.txt"))
        act("s")
        eq("M  a.txt\n", get_git_status("a.txt"))
      end)
    )

    it(
      "can stage a hunk under the cursor of a tracked file",
      in_prepared_repo(function()
        find("Modified a%.txt")
        act("<tab>jjs")
        eq("MM a.txt\n", get_git_status("a.txt"))
        eq(
          [[--- a/a.txt
+++ b/a.txt
@@ -1,5 +1,5 @@
 This is a text file under version control.
-It exists so it can be manipulated by the test suite.
+This is a change made to a tracked file.
 Here are some lines we can change during the tests.
 
 
]],
          get_git_diff("a.txt", "--cached")
        )
      end)
    )

    it(
      "can stage a subsequent hunk under the cursor of a tracked file",
      in_prepared_repo(function()
        find("Modified a%.txt")
        act("<tab>8js")
        eq("MM a.txt\n", get_git_status("a.txt"))
        eq(
          [[--- a/a.txt
+++ b/a.txt
@@ -7,4 +7,5 @@ Here are some lines we can change during the tests.
 
 This is a second block of text to create a second hunk.
 It also has some line we can manipulate.
+Adding a new line right here!
 Here is some more.
]],
          get_git_diff("a.txt", "--cached")
        )
      end)
    )

    it(
      "can stage from a selection in a hunk",
      in_prepared_repo(function()
        find("Modified a%.txt")
        act("<tab>jjjjVs")
        -- eq("M  a.txt\n", get_git_status("a.txt"))
        eq(
          [[--- a/a.txt
+++ b/a.txt
@@ -1,5 +1,6 @@
 This is a text file under version control.
 It exists so it can be manipulated by the test suite.
+This is a change made to a tracked file.
 Here are some lines we can change during the tests.
 
 
]],
          get_git_diff("a.txt", "--cached")
        )
      end)
    )
  end)

  describe("unstaging files - u", function()
    it(
      "can unstage a staged file under the cursor",
      in_prepared_repo(function()
        find("Modified b%.txt")
        eq("M  b.txt\n", get_git_status("b.txt"))
        act("u")
        eq(" M b.txt\n", get_git_status("b.txt"))
      end)
    )

    it(
      "can unstage a hunk under the cursor of a staged file",
      in_prepared_repo(function()
        find("Modified b%.txt")
        act("<tab>jju")
        eq("MM b.txt\n", get_git_status("b.txt"))
        eq(
          [[--- a/b.txt
+++ b/b.txt
@@ -7,3 +7,4 @@ This way, unstaging staged changes can be tested.
 Some more lines down here to force a second hunk.
 I can't think of anything else.
 Duh.
+And here as well
]],
          get_git_diff("b.txt", "--cached")
        )
      end)
    )

    it(
      "can unstage from a selection in a hunk",
      in_prepared_repo(function()
        find("Modified b%.txt")
        act("<tab>jjjjVu")
        eq("MM b.txt\n", get_git_status("b.txt"))
        eq(
          [[--- a/b.txt
+++ b/b.txt
@@ -1,4 +1,5 @@
 This is another test file.
+Changes here!
 This way, unstaging staged changes can be tested.
 
 
]],
          get_git_diff("b.txt")
        )
      end)
    )

    it(
      "can unstage a subsequent hunk from a staged file",
      in_prepared_repo(function()
        find("Modified b%.txt")
        act("<tab>8ju")
        eq("MM b.txt\n", get_git_status("b.txt"))
        eq(
          [[--- a/b.txt
+++ b/b.txt
@@ -7,3 +7,4 @@ This way, unstaging staged changes can be tested.
 Some more lines down here to force a second hunk.
 I can't think of anything else.
 Duh.
+And here as well
]],
          get_git_diff("b.txt")
        )
      end)
    )
  end)

  describe("discarding files - x", function()
    it(
      "can discard the changes of a file under the cursor",
      in_prepared_repo(function()
        find("Modified a%.txt")
        act("x")
        eq("", get_git_status("a.txt"))
      end)
    )

    it(
      "can discard a hunk under the cursor",
      in_prepared_repo(function()
        find("Modified a%.txt")
        act("<tab>jjx")
        eq(" M a.txt\n", get_git_status("a.txt"))
        eq(
          [[--- a/a.txt
+++ b/a.txt
@@ -7,4 +7,5 @@ Here are some lines we can change during the tests.
 
 This is a second block of text to create a second hunk.
 It also has some line we can manipulate.
+Adding a new line right here!
 Here is some more.
]],
          get_git_diff("a.txt")
        )
      end)
    )

    it(
      "can discard a selection of a hunk",
      in_prepared_repo(function()
        find("Modified a%.txt")
        act("<tab>jjjjVx")
        eq(" M a.txt\n", get_git_status("a.txt"))
        eq(
          [[--- a/a.txt
+++ b/a.txt
@@ -1,5 +1,4 @@
 This is a text file under version control.
-It exists so it can be manipulated by the test suite.
 Here are some lines we can change during the tests.
 
 
@@ -7,4 +6,5 @@ Here are some lines we can change during the tests.
 
 This is a second block of text to create a second hunk.
 It also has some line we can manipulate.
+Adding a new line right here!
 Here is some more.
]],
          get_git_diff("a.txt")
        )
      end)
    )

    it(
      "can delete an untracked file",
      in_prepared_repo(function()
        find("untracked%.txt")
        act("x")
        eq("", get_git_status("untracked.txt"))
      end)
    )

    it(
      "can discard the changes of a staged file under the cursor",
      in_prepared_repo(function()
        find("Modified b%.txt")
        act("x")
        eq("", get_git_status("b.txt"))
      end)
    )

    it(
      "can discard a hunk of the staged file under the cursor",
      in_prepared_repo(function()
        find("Modified b%.txt")
        act("<tab>jjx")
        eq("M  b.txt\n", get_git_status("b.txt"))
        eq(
          [[--- a/b.txt
+++ b/b.txt
@@ -7,3 +7,4 @@ This way, unstaging staged changes can be tested.
 Some more lines down here to force a second hunk.
 I can't think of anything else.
 Duh.
+And here as well
]],
          get_git_diff("b.txt", "--cached")
        )
      end)
    )

    it(
      "can discard a selection of a staged file",
      in_prepared_repo(function()
        find("Modified b%.txt")
        act("<tab>jjjjVx")
        eq("M  b.txt\n", get_git_status("b.txt"))
        eq(
          [[--- a/b.txt
+++ b/b.txt
@@ -1,5 +1,4 @@
 This is another test file.
-It will have staged changes.
 This way, unstaging staged changes can be tested.
 
 
@@ -7,3 +6,4 @@ This way, unstaging staged changes can be tested.
 Some more lines down here to force a second hunk.
 I can't think of anything else.
 Duh.
+And here as well
]],
          get_git_diff("b.txt", "--cached")
        )
      end)
    )
  end)

  describe("recent commits", function()
    local recent_commit_pattern = "Recent commits %(%d+%)"

    local function refresh_status_buffer()
      act("<c-r>")
      require("plenary.async").util.block_on(status.reset)
    end

    local function create_new_commits(message, number_of_commits)
      system("git stash && git stash clear && git clean -ffdx")
      local commit_commands =
        string.format("printf 'Some Content\\n' >> a-file && git add a-file && git commit -m '%s'", message)

      if number_of_commits == 1 then
        system(commit_commands)
      else
        local loop_cmd = string.format(
          [[
          COUNT=1
          while [ "$COUNT" -ne %s ]; do
            %s
            COUNT=$((COUNT + 1))
          done
          ]],
          number_of_commits,
          commit_commands
        )
        system(loop_cmd)
      end
      refresh_status_buffer()
    end

    describe("count", function()
      it(
        "has the correct number of recent commits",
        in_prepared_repo(function()
          local line = find(recent_commit_pattern)
          local recent_commit_count = tonumber(string.match(line, "%d+"))
          local repo_commit_count = tonumber(system("git rev-list master --count"))
          assert.are.equal(recent_commit_count, repo_commit_count)
        end)
      )

      it(
        "has the correct number when there are more commits than recent_commit_count",
        in_prepared_repo(function()
          create_new_commits("A commit to increase commit number", 50)
          local line = find(recent_commit_pattern)
          local recent_commit_count = tonumber(string.match(line, "%d+"))
          local repo_commit_count = tonumber(system("git rev-list master --count"))
          local config_commit_count = 10
          require("neogit.config").values.status.recent_commit_count = config_commit_count

          print("Recent Commit Count: " .. recent_commit_count)
          print("Config Commit Count: " .. config_commit_count)
          print("Repository Commit Count: " .. repo_commit_count)
          -- Ensures the actual number of recent commits is less than the repo commits.
          -- The total number of repo commits SHOULD be more than the recent commit count.
          assert.True(recent_commit_count < repo_commit_count)
          -- Ensure the number of recent commits is equal to the number specified in the config
          assert.are.equal(recent_commit_count, config_commit_count)
        end)
      )
    end)
    describe("content", function()
      local function get_latest_recent_commit()
        -- Get the commit right under the "Recent commits" message
        local _, cursor_row = find(recent_commit_pattern)
        act("<tab>")
        vim.api.nvim_win_set_cursor(0, { cursor_row + 1, 0 })
        local commit_message_line = vim.api.nvim_buf_get_lines(0, cursor_row, cursor_row + 1, true)[1]
        -- Remove the leading commit hash
        local commit_message = string.gsub(commit_message_line, "^[a-z0-9]+ ", "")

        return commit_message
      end

      it(
        "has correct recent commit information with the default config",
        in_prepared_repo(function()
          local new_commit_message = "a commit"
          create_new_commits(new_commit_message, 1)

          local commit_message = get_latest_recent_commit()
          print("Got commit message as: " .. commit_message)

          assert.are.same(new_commit_message, commit_message)
        end)
      )

      it(
        "has correct recent commit information with extra author info",
        in_prepared_repo(function()
          require("neogit.config").values.status.recent_commit_include_author_info = true
          local new_commit_message = "a commit"
          create_new_commits(new_commit_message, 1)

          local commit_message = get_latest_recent_commit()
          print("Got commit message as: " .. commit_message)

          new_commit_message =
            string.format("[%s] <%s> %s", "Neogit Test User", "test@neogit.git", new_commit_message)
          assert.are.same(new_commit_message, commit_message)
        end)
      )
    end)
  end)
end)
