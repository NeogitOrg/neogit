local config = require("neogit.config")

describe("Neogit config", function()
  before_each(function()
    config.values = config.get_default_values()
  end)
  describe("validation", function()
    describe("for bad configs", function()
      it("should return invalid when the base config isn't a table", function()
        config.values = "INVALID CONFIG"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when disable_hint isn't a boolean", function()
        config.values.disable_hint = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when disable_context_highlighting isn't a boolean", function()
        config.values.disable_context_highlighting = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when disable_signs isn't a boolean", function()
        config.values.disable_signs = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when telescope_sorter isn't a function", function()
        config.values.telescope_sorter = "not a function"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when disable_insert_on_commit isn't a boolean", function()
        config.values.telescope_sorter = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when use_per_project_settings isn't a boolean", function()
        config.values.use_per_project_settings = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when remember_settings isn't a boolean", function()
        config.values.remember_settings = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when remember_settings isn't a boolean", function()
        config.values.remember_settings = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sort_branches isn't a string", function()
        config.values.sort_branches = false
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when initial_branch_name isn't a string", function()
        config.values.initial_branch_name = false
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when kind isn't a string", function()
        config.values.kind = true
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when kind isn't a valid kind", function()
        config.values.kind = "not a valid kind"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when disable_line_numbers isn't a boolean", function()
        config.values.disable_line_numbers = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when console_timeout isn't a number", function()
        config.values.console_timeout = "not a number"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when auto_show_console isn't a boolean", function()
        config.values.auto_show_console = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when auto_show_console_on isn't a string", function()
        config.values.auto_show_console_on = true
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when status isn't a table", function()
        config.values.status = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when status.recent_commit_count isn't a number", function()
        config.values.status.recent_commit_count = "not a number"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when commit_editor isn't a table", function()
        config.values.commit_editor = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when commit_editor.kind isn't a string", function()
        config.values.commit_editor.kind = false
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when commit_editor.kind isn't a valid kind", function()
        config.values.commit_editor.kind = "not a valid kind"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when commit_select_view isn't a table", function()
        config.values.commit_select_view = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when commit_select_view.kind isn't a string", function()
        config.values.commit_select_view.kind = "not a string"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when commit_select_view.kind isn't a valid kind", function()
        config.values.commit_select_view.kind = "not a valid kind"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when commit_view isn't a table", function()
        config.values.commit_view = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when commit_view.kind isn't a string", function()
        config.values.commit_view.kind = "not a string"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when commit_view.kind isn't a valid kind", function()
        config.values.commit_view.kind = "not a valid kind"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when log_view isn't a table", function()
        config.values.log_view = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when log_view.kind isn't a string", function()
        config.values.log_view.kind = "not a string"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when log_view.kind isn't a valid kind", function()
        config.values.log_view.kind = "not a valid kind"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when rebase_editor isn't a table", function()
        config.values.rebase_editor = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when rebase_editor.kind isn't a string", function()
        config.values.rebase_editor.kind = "not a string"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when rebase_editor.kind isn't a valid kind", function()
        config.values.rebase_editor.kind = "not a valid kind"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when reflog_view isn't a table", function()
        config.values.reflog_view = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when reflog_view.kind isn't a string", function()
        config.values.reflog_view.kind = "not a string"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when reflog_view.kind isn't a valid kind", function()
        config.values.reflog_view.kind = "not a valid kind"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when merge_editor isn't a table", function()
        config.values.merge_editor = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when merge_editor.kind isn't a string", function()
        config.values.merge_editor.kind = "not a string"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when merge_editor.kind isn't a valid kind", function()
        config.values.merge_editor.kind = "not a valid kind"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when preview_buffer isn't a table", function()
        config.values.preview_buffer = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when preview_buffer.kind isn't a string", function()
        config.values.preview_buffer.kind = "not a string"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when preview_buffer.kind isn't a valid kind", function()
        config.values.preview_buffer.kind = "not a valid kind"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when popup isn't a table", function()
        config.values.popup = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when popup.kind isn't a string", function()
        config.values.popup.kind = "not a string"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when popup.kind isn't a valid kind", function()
        config.values.popup.kind = "not a valid kind"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when signs isn't a table", function()
        config.values.signs = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when signs.hunk isn't valid", function()
        config.values.signs.hunk = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when signs.hunk is not of size 2", function()
        config.values.signs.hunk = { "" }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when signs.hunk elements aren't strings", function()
        config.values.signs.hunk = { false, "" }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)

        config.values.signs.hunk = { "", false }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)

        config.values.signs.hunk = { false, false }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when signs.item isn't valid", function()
        config.values.signs.item = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when signs.item is not of size 2", function()
        config.values.signs.item = { "" }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when signs.item elements aren't strings", function()
        config.values.signs.item = { false, "" }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)

        config.values.signs.item = { "", false }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)

        config.values.signs.item = { false, false }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when signs.section isn't valid", function()
        config.values.signs.section = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when signs.section is not of size 2", function()
        config.values.signs.section = { "" }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when signs.section elements aren't strings", function()
        config.values.signs.section = { false, "" }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)

        config.values.signs.section = { "", false }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)

        config.values.signs.section = { false, false }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when integrations isn't a table", function()
        config.values.integrations = false
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections isn't a table", function()
        config.values.sections = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections isn't a table", function()
        config.values.sections = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.untracked isn't a table", function()
        config.values.sections.untracked = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.untracked.folded isn't a boolean", function()
        config.values.sections.untracked.folded = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.unstaged isn't a table", function()
        config.values.sections.unstaged = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.unstaged.folded isn't a boolean", function()
        config.values.sections.unstaged.folded = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.staged isn't a table", function()
        config.values.sections.staged = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.staged.folded isn't a boolean", function()
        config.values.sections.staged.folded = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.stashes isn't a table", function()
        config.values.sections.stashes = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.stashes.folded isn't a boolean", function()
        config.values.sections.stashes.folded = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.unpulled_upstream isn't a table", function()
        config.values.sections.unpulled_upstream = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.unpulled.folded_upstream isn't a boolean", function()
        config.values.sections.unpulled_upstream.folded = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.unpulled_pushRemote isn't a table", function()
        config.values.sections.unpulled_pushRemote = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.unpulled_pushRemote.folded_upstream isn't a boolean", function()
        config.values.sections.unpulled_pushRemote.folded = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.unmerged_upstream isn't a table", function()
        config.values.sections.unmerged_upstream = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.unmerged_upstream.folded isn't a boolean", function()
        config.values.sections.unmerged_upstream.folded = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.unmerged_pushRemote isn't a table", function()
        config.values.sections.unmerged_pushRemote = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.unmerged_pushRemote.folded isn't a boolean", function()
        config.values.sections.unmerged_pushRemote.folded = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.recent isn't a table", function()
        config.values.sections.recent = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.recent.folded isn't a boolean", function()
        config.values.sections.recent.folded = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.rebase isn't a table", function()
        config.values.sections.rebase = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when sections.rebase.folded isn't a boolean", function()
        config.values.sections.rebase.folded = "not a boolean"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when ignored_settings isn't a table", function()
        config.values.ignored_settings = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when ignored_settings isn't a table", function()
        config.values.ignored_settings = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when ignored_settings has an invalid setting format", function()
        config.values.ignored_settings = { "invalid setting format!", "Filetype-yep", "Neogit+example" }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)

        config.values.ignored_settings = { "Valid--format", "Invalid-format" }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      it("should return invalid when mappings isn't a table", function()
        config.values.mappings = "not a table"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
      end)

      describe("finder mappings", function()
        it("should return invalid when it's not a table", function()
          config.values.mappings.finder = "not a table"
          assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
        end)

        it("should return invalid when a individual mapping is not a string", function()
          config.values.mappings.finder = {
            ["c"] = { { "Close" } },
          }
          assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
        end)

        it("should return invalid when a command mapping is not known", function()
          config.values.mappings.finder = {
            ["c"] = { "Invalid Command" },
          }
          assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
        end)
      end)
      describe("status mappings", function()
        it("should return invalid when it's not a table", function()
          config.values.mappings.status = "not a table"
          assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
        end)

        it("should return invalid when a mapping is not a string or boolean", function()
          config.values.mappings.status = {
            ["Close"] = {},
          }
          assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
        end)

        it("should return invalid when a command mapping is not known", function()
          config.values.mappings.status = {
            ["Invalid Command"] = "c",
          }
          assert.True(vim.tbl_count(require("neogit.config").validate_config()) ~= 0)
        end)
      end)
    end)

    describe("for good configs", function()
      it("should return valid for the default config", function()
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when kind is a valid window kind", function()
        config.values.kind = "floating"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when disable_line_numbers is a boolean", function()
        config.values.disable_line_numbers = true
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when commit_editor.kind is a valid window kind", function()
        config.values.commit_editor.kind = "replace"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when commit_select_view.kind is a valid window kind", function()
        config.values.commit_select_view.kind = "tab"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when commit_view.kind is a valid window kind", function()
        config.values.commit_view.kind = "split_above"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when log_view.kind is a valid window kind", function()
        config.values.log_view.kind = "vsplit"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when rebase_editor.kind is a valid window kind", function()
        config.values.rebase_editor.kind = "vsplit"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when reflog_view.kind is a valid window kind", function()
        config.values.reflog_view.kind = "vsplit"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when merge_editor.kind is a valid window kind", function()
        config.values.merge_editor.kind = "tab"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when preview_buffer.kind is a valid window kind", function()
        config.values.preview_buffer.kind = "floating"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when popup.kind is a valid window kind", function()
        config.values.popup.kind = "floating"
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when ignored_settings has a valid setting", function()
        config.values.ignored_settings = { "Valid--setting-format" }
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when a command mappings.status is a boolean", function()
        config.values.mappings.status["c"] = false
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when a command mappings.status is a function", function()
        config.values.mappings.status["c"] = function()
          print("Well hello there :)")
        end
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)

      it("should return valid when a command mappings.finder is a boolean", function()
        config.values.mappings.finder["c"] = false
        assert.True(vim.tbl_count(require("neogit.config").validate_config()) == 0)
      end)
    end)
  end)
end)
