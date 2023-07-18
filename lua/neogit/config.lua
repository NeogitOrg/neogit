local M = {}

function M.get_copy()
  return vim.tbl_deep_extend("force", M.values, {})
end

function M.get_default_values()
  return {
    disable_hint = false,
    disable_context_highlighting = false,
    disable_signs = false,
    disable_commit_confirmation = false,
    disable_builtin_notifications = false,
    telescope_sorter = function()
      return nil
    end,
    disable_insert_on_commit = true,
    use_per_project_settings = true,
    remember_settings = true,
    auto_refresh = true,
    sort_branches = "-committerdate",
    kind = "tab",
    -- The time after which an output console is shown for slow running commands
    console_timeout = 2000,
    -- Automatically show console if a command takes more than console_timeout milliseconds
    auto_show_console = true,
    status = {
      recent_commit_count = 10,
    },
    commit_editor = {
      kind = "split",
    },
    commit_select_view = {
      kind = "tab",
    },
    commit_view = {
      kind = "vsplit",
    },
    log_view = {
      kind = "tab",
    },
    rebase_editor = {
      kind = "split",
    },
    reflog_view = {
      kind = "tab",
    },
    merge_editor = {
      kind = "split",
    },
    preview_buffer = {
      kind = "split",
    },
    popup = {
      kind = "split",
    },
    signs = {
      hunk = { "", "" },
      item = { ">", "v" },
      section = { ">", "v" },
    },
    integrations = setmetatable({}, {
      __index = function(_, key)
        local ok, value = pcall(require, key)
        return ok and value or false
      end,
    }),
    sections = {
      untracked = {
        folded = false,
      },
      unstaged = {
        folded = false,
      },
      staged = {
        folded = false,
      },
      stashes = {
        folded = true,
      },
      unpulled = {
        folded = true,
      },
      unmerged = {
        folded = false,
      },
      recent = {
        folded = true,
      },
      rebase = {
        folded = true,
      },
    },
    ignored_settings = {
      "NeogitPushPopup--force-with-lease",
      "NeogitPushPopup--force",
      "NeogitCommitPopup--allow-empty",
      "NeogitRevertPopup--no-edit", -- TODO: Fix incompatible switches with default enables
    },
    mappings = {
      finder = {
        ["Select"] = { "<cr>" },
        ["Close"] = { "<c-c>", "<esc>" },
        ["Next"] = { "<c-n>", "<down>" },
        ["Previous"] = { "<c-p>", "<up>" },
        ["MultiselectToggleNext"] = { "<tab>" },
        ["MultiselectTogglePrevious"] = { "<s-tab>" },
        ["NOP"] = { "<c-j>" },
      },
      status = {
        ["Close"] = "q",
        ["InitRepo"] = "I",
        ["Depth1"] = "1",
        ["Depth2"] = "2",
        ["Depth3"] = "3",
        ["Depth4"] = "4",
        ["Toggle"] = "<tab>",
        ["Discard"] = "x",
        ["Stage"] = "s",
        ["StageUnstaged"] = "S",
        ["StageAll"] = "<c-s>",
        ["Unstage"] = "u",
        ["UnstageStaged"] = "U",
        ["DiffAtFile"] = "d",
        ["CommandHistory"] = "$",
        ["Console"] = "#",
        ["RefreshBuffer"] = "<c-r>",
        ["GoToFile"] = "<enter>",
        ["VSplitOpen"] = "<c-v>",
        ["SplitOpen"] = "<c-x>",
        ["TabOpen"] = "<c-t>",
        ["HelpPopup"] = "?",
        ["DiffPopup"] = "D",
        ["PullPopup"] = "p",
        ["RebasePopup"] = "r",
        ["MergePopup"] = "m",
        ["PushPopup"] = "P",
        ["CommitPopup"] = "c",
        ["LogPopup"] = "L",
        ["RevertPopup"] = "_",
        ["StashPopup"] = "Z",
        ["CherryPickPopup"] = "A",
        ["BranchPopup"] = "b",
        ["FetchPopup"] = "f",
        ["ResetPopup"] = "X",
        ["RemotePopup"] = "M",
        ["GoToPreviousHunkHeader"] = "{",
        ["GoToNextHunkHeader"] = "}",
      },
    },
  }
end

M.values = M.get_default_values()

---Validates the config
---@return boolean false if the config is invalid
---@return string all error messages emitted during validation
function M.validate_config()
  local config = M.values

  ---@type boolean
  local validation_ok = true
  ---@type string[]
  local errors = {}
  local function err(msg)
    validation_ok = false
    table.insert(errors, msg)
  end

  local function present_errors()
    local header = "====Neogit Configuration Errors===="
    local header_message = {
      "Neogit has NOT been setup!",
      "You have a misconfiguration in your Neogit setup!",
      'Validate that your configuration passed to `require("neogit").setup()` is valid!',
    }
    local header_sep = function()
      local sep = ""
      for _ = 0, string.len(header), 1 do
        sep = sep .. "-"
      end

      return sep
    end
    if validation_ok then
      return ""
    else
      return string.format("%s\n%s\n%s\n", header, table.concat(header_message, "\n"), header_sep())
        .. table.concat(errors, "\n")
    end
  end

  ---Checks if a variable is the correct, type if not it calls err with an error string
  ---@param value any
  ---@param name string
  ---@param expected_type type
  local function validate_type(value, name, expected_type)
    if type(value) ~= expected_type then
      err(string.format("Expected '%s' to be of type '%s', got '%s'", name, expected_type, type(value)))
      return false
    end
    return true
  end

  -- More complex validation functions go below
  local function validate_kind(val, name)
    if
      validate_type(val, name, "string")
      and not vim.tbl_contains({ "split", "vsplit", "tab", "floating", "auto" }, val)
    then
      err(
        string.format(
          "Expected %s to be one of 'split', 'vsplit', 'tab', 'floating', or 'auto', got '%s'",
          name,
          val
        )
      )
    end
  end

  local function validate_signs()
    if not validate_type(config.signs, "signs", "table") then
      return
    end

    local function validate_signs_table(tbl_name, tbl)
      if type(tbl) ~= "table" then
        err(string.format("Expected signs.%s to be of type 'table'!", tbl_name))
      else
        if #tbl ~= 2 then
          err(
            string.format("Expected for signs.%s to %s elements, it had %s elements!", tbl_name, #tbl, #tbl)
          )
        elseif type(tbl[1]) ~= "string" then
          err(
            string.format(
              "Expected element one of signs.%s to be of type 'string', it was of type '%s'",
              tbl_name,
              tbl[1],
              type(tbl[1])
            )
          )
        elseif type(tbl[2]) ~= "string" then
          err(
            string.format(
              "Expected element two of signs.%s to be of type 'string', it was of type '%s'",
              tbl_name,
              tbl[2],
              type(tbl[2])
            )
          )
        end
      end
    end

    validate_signs_table("hunk", config.signs.hunk)
    validate_signs_table("item", config.signs.item)
    validate_signs_table("section", config.signs.section)
  end

  local function validate_disable_insert_on_commit()
    local err_msg = "Expected either a string with value 'auto' or a boolean value"
    if type(config.disable_insert_on_commit) == "string" then
      if config.disable_insert_on_commit ~= "auto" then
        err(err_msg)
      end
    elseif type(config.disable_insert_on_commit) ~= "boolean" then
      err(err_msg)
    end
  end

  local function validate_integrations()
    local valid_integrations = { "diffview", "telescope" }
    if not validate_type(config.integrations, "integrations", "table") or #config.integrations == 0 then
      return
    end
    for integration_name, _ in pairs(config.integrations) do
      if not vim.tbl_contains(valid_integrations, integration_name) then
        err(
          string.format(
            "Expected a valid integration, received '%s', which is not a supported integration! Valid integrations: ",
            integration_name,
            table.concat(valid_integrations, ", ")
          )
        )
      end
    end
  end

  local function validate_sections()
    if not validate_type(config.sections, "sections", "table") then
      return
    end

    for section_name, section in pairs(config.sections) do
      validate_type(section, "section." .. section_name, "table")
      validate_type(section.folded, string.format("section.%s.folded", section_name), "boolean")
    end
  end

  local function validate_ignored_settings()
    if not validate_type(config.ignored_settings, "ignored_settings", "table") then
      return
    end

    for _, setting in ipairs(config.ignored_settings) do
      if validate_type(setting, "ignored_settings." .. vim.inspect(setting), "string") then
        local match_pattern = ".+%-%-.+"
        if not string.match(setting, match_pattern) then
          err(
            string.format(
              "An ignored_settings setting did not match %s (format: filetype--flag), setting was: %s",
              match_pattern,
              setting
            )
          )
        end
      end
    end
  end

  local function validate_mappings()
    if not validate_type(config.mappings, "mappings", "table") then
      return
    end

    -- Validate mappings.finder
    local valid_finder_commands = {}

    for cmd, _ in pairs(M.get_default_values().mappings.finder) do
      table.insert(valid_finder_commands, cmd)
    end

    local function validate_finder_map(command, key_binds)
      if
        not validate_type(command, "mappings.finder ->" .. vim.inspect(command), "string")
        or not validate_type(key_binds, "mappings.finder." .. vim.inspect(command), "table")
      then
        return
      end

      if not vim.tbl_contains(valid_finder_commands, command) then
        err(
          string.format(
            "Expected a valid finder command, got '%s'. Valid finder commands: { %s }",
            command,
            table.concat(valid_finder_commands, ", ")
          )
        )
      end

      for _, key in ipairs(key_binds) do
        validate_type(key, string.format("mappings.finder.%s -> %s", command, vim.inspect(key)), "string")
      end
    end

    if validate_type(config.mappings.finder, "mappings.finder", "table") then
      for command, key_binds in pairs(config.mappings.finder) do
        validate_finder_map(command, key_binds)
      end
    end

    -- Validate mappings.status
    local valid_status_commands = {}

    for cmd, _ in pairs(M.get_default_values().mappings.status) do
      table.insert(valid_status_commands, cmd)
    end

    if validate_type(config.mappings.status, "mappings.status", "table") then
      for command, key in pairs(config.mappings.status) do
        if
          validate_type(command, "mappings.status -> " .. vim.inspect(command), "string")
          and validate_type(key, "mappings.status." .. command, "string")
        then
          if not vim.tbl_contains(valid_status_commands, command) then
            err(
              string.format(
                "Expected a valid status command, got '%s'. Valid finder commands: { %s }",
                command,
                table.concat(valid_status_commands, ", ")
              )
            )
          end
        end
      end
    end
  end

  if validate_type(config, "base config", "table") then
    validate_type(config.disable_hint, "disable_hint", "boolean")
    validate_type(config.disable_context_highlighting, "disable_context_highlighting", "boolean")
    validate_type(config.disable_signs, "disable_signs", "boolean")
    validate_type(config.disable_commit_confirmation, "disable_commit_confirmation", "boolean")
    validate_type(config.disable_builtin_notifications, "disable_builtin_notifications", "boolean")
    validate_type(config.telescope_sorter, "telescope_sorter", "function")
    validate_type(config.use_per_project_settings, "use_per_project_settings", "boolean")
    validate_type(config.remember_settings, "remember_settings", "boolean")
    validate_type(config.auto_refresh, "auto_refresh", "boolean")
    validate_type(config.sort_branches, "sort_branches", "string")
    validate_type(config.console_timeout, "console_timeout", "number")
    validate_kind(config.kind)
    validate_type(config.auto_show_console, "auto_show_console", "boolean")
    if validate_type(config.status, "status", "table") then
      validate_type(config.status.recent_commit_count, "status.recent_commit_count", "number")
    end
    validate_signs()
    validate_disable_insert_on_commit()
    -- Commit Editor
    if validate_type(config.commit_editor, "commit_editor", "table") then
      validate_kind(config.commit_editor.kind, "commit_editor")
    end
    -- Commit Select View
    if validate_type(config.commit_select_view, "commit_select_view", "table") then
      validate_kind(config.commit_select_view.kind, "config.commit_select_view.kind")
    end
    -- Commit View
    if validate_type(config.commit_view, "commit_view", "table") then
      validate_kind(config.commit_view.kind, "commit_view.kind")
    end
    -- Log View
    if validate_type(config.log_view, "log_view", "table") then
      validate_kind(config.log_view.kind, "log_view.kind")
    end
    -- Rebase Editor
    if validate_type(config.rebase_editor, "rebase_editor", "table") then
      validate_kind(config.rebase_editor.kind, "rebase_editor.kind")
    end
    -- Reflog View
    if validate_type(config.reflog_view, "reflog_view", "table") then
      validate_kind(config.reflog_view.kind, "reflog_view.kind")
    end
    -- Merge Editor
    if validate_type(config.merge_editor, "merge_editor", "table") then
      validate_kind(config.merge_editor.kind, "merge_editor.kind")
    end
    -- Preview Buffer
    if validate_type(config.preview_buffer, "preview_buffer", "table") then
      validate_kind(config.preview_buffer.kind, "preview_buffer.kind")
    end
    -- Popup
    if validate_type(config.popup, "popup", "table") then
      validate_kind(config.popup.kind, "popup.kind")
    end

    validate_integrations()
    validate_sections()
    validate_ignored_settings()
    validate_mappings()
  end

  return unpack { validation_ok, present_errors() }
end

function M.ensure_integration(name)
  if not M.values.integrations[name] then
    vim.api.nvim_err_writeln(string.format("Neogit: `%s` integration is not enabled", name))
    return false
  end

  return true
end

return M
