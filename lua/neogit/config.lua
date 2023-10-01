local util = require("neogit.lib.util")
local M = {}

---@return table<string, string[]>
--- Returns a map of commands, mapped to the list of keys which trigger them.
function M.get_reversed_status_maps()
  local result = {}
  for k, v in pairs(M.values.mappings.status) do
    -- If `v == false` the mapping is disabled
    if v then
      local current = result[v]
      if current then
        table.insert(current, k)
      else
        result[v] = { k }
      end
    end
  end

  return result
end

---@alias WindowKind
---|"split" Open in a split
---| "vsplit" Open in a vertical split
---| "float" Open in a floating window
---| "tab" Open in a new tab

---@class NeogitCommitBufferConfig Commit buffer options
---@field kind WindowKind The type of window that should be opened
---@field verify_commit boolean Show commit signature information in the buffer

---@class NeogitConfigPopup Popup window options
---@field kind WindowKind The type of window that should be opened

---@alias NeogitConfigSignsIcon { [1]: string, [2]: string }

---@class NeogitConfigSigns
---@field hunk NeogitConfigSignsIcon The icons to use for open and closed hunks
---@field item NeogitConfigSignsIcon The icons to use for open and closed items
---@field section NeogitConfigSignsIcon The icons to use for open and closed sections

---@class NeogitConfigSection A section to show in the Neogit Status buffer, e.g. Staged/Unstaged/Untracked
---@field folded boolean Whether or not this section should be open or closed by default
---@field hidden boolean Whether or not this section should be shown

---@class NeogitConfigSections
---@field untracked NeogitConfigSection|nil
---@field unstaged NeogitConfigSection|nil
---@field staged NeogitConfigSection|nil
---@field stashes NeogitConfigSection|nil
---@field unpulled_upstream NeogitConfigSection|nil
---@field unmerged_upstream NeogitConfigSection|nil
---@field unpulled_pushRemote NeogitConfigSection|nil
---@field unmerged_pushRemote NeogitConfigSection|nil
---@field recent NeogitConfigSection|nil
---@field rebase NeogitConfigSection|nil
---@field sequencer NeogitConfigSection|nil

---@class NeogitFilewatcherConfig
---@field interval number
---@field enabled boolean
---@field filewatcher NeogitFilewatcherConfig|nil

---@alias NeogitConfigMappingsFinder "Select" | "Close" | "Next" | "Previous" | "MultiselectToggleNext" | "MultiselectTogglePrevious" | "NOP" | false
---@alias NeogitConfigMappingsStatus "Close" | "InitRepo" | "Depth1" | "Depth2" | "Depth3" | "Depth4" | "Toggle" | "Discard" | "Stage" | "StageUnstaged" | "StageAll" | "Unstage" | "UnstageStaged" | "DiffAtFile" | "CommandHistory" | "Console" | "RefreshBuffer" | "GoToFile" | "VSplitOpen" | "SplitOpen" | "TabOpen" | "HelpPopup" | "DiffPopup" | "PullPopup" | "RebasePopup" | "MergePopup" | "PushPopup" | "CommitPopup" | "IgnorePopup" | "LogPopup" | "RevertPopup" | "StashPopup" | "CherryPickPopup" | "BranchPopup" | "FetchPopup" | "ResetPopup" | "RemotePopup" | "GoToPreviousHunkHeader" | "GoToNextHunkHeader" | false | fun()

---@class NeogitConfigMappings Consult the config file or documentation for values
---@field finder? { [string]: NeogitConfigMappingsFinder } A dictionary that uses finder commands to set multiple keybinds
---@field status? { [string]: NeogitConfigMappingsStatus } A dictionary that uses status commands to set a single keybind

---@class NeogitConfig Neogit configuration settings
---@field filewatcher? NeogitFilewatcherConfig Values for filewatcher
---@field disable_hint? boolean Remove the top hint in the Status buffer
---@field disable_context_highlighting? boolean Disable context highlights based on cursor position
---@field disable_signs? boolean Special signs to draw for sections etc. in Neogit
---@field git_services? table Templartes to use when opening a pull request for a branch
---@field disable_commit_confirmation? boolean Disable commit confirmations
---@field telescope_sorter? function The sorter telescope will use
---@field disable_insert_on_commit? boolean|"auto" Disable automatically entering insert mode in commit dialogues
---@field use_per_project_settings? boolean Scope persisted settings on a per-project basis
---@field remember_settings? boolean Whether neogit should persist flags from popups, e.g. git push flags
---@field auto_refresh? boolean Automatically refresh to detect git modifications without manual intervention
---@field sort_branches? string Value used for `--sort` for the `git branch` command
---@field kind? WindowKind The default type of window neogit should open in
---@field disable_line_numbers? boolean Whether to disable line numbers
---@field console_timeout? integer Time in milliseconds after a console is created for long running commands
---@field auto_show_console? boolean Automatically show the console if a command takes longer than console_timout
---@field status? { recent_commit_count: integer } Status buffer options
---@field commit_editor? NeogitConfigPopup Commit editor options
---@field commit_select_view? NeogitConfigPopup Commit select view options
---@field commit_view? NeogitCommitBufferConfig Commit buffer options
---@field log_view? NeogitConfigPopup Log view options
---@field rebase_editor? NeogitConfigPopup Rebase editor options
---@field reflog_view? NeogitConfigPopup Reflog view options
---@field merge_editor? NeogitConfigPopup Merge editor options
---@field tag_editor? NeogitConfigPopup Tag editor options
---@field preview_buffer? NeogitConfigPopup Preview options
---@field popup? NeogitConfigPopup Set the default way of opening popups
---@field signs? NeogitConfigSigns Signs used for toggled regions
---@field integrations? { diffview: boolean, telescope: boolean, fzf_lua: boolean } Which integrations to enable
---@field sections? NeogitConfigSections
---@field ignored_settings? string[] Settings to never persist, format: "Filetype--cli-value", i.e. "NeogitCommitPopup--author"
---@field mappings? NeogitConfigMappings
---@field notification_icon? String

---Returns the default Neogit configuration
---@return NeogitConfig
function M.get_default_values()
  return {
    disable_hint = false,
    disable_context_highlighting = false,
    disable_signs = false,
    disable_commit_confirmation = false,
    filewatcher = {
      interval = 1000,
      enabled = false,
    },
    telescope_sorter = function()
      return nil
    end,
    git_services = {
      ["github.com"] = "https://github.com/${owner}/${repository}/compare/${branch_name}?expand=1",
      ["bitbucket.org"] = "https://bitbucket.org/${owner}/${repository}/pull-requests/new?source=${branch_name}&t=1",
      ["gitlab.com"] = "https://gitlab.com/${owner}/${repository}/merge_requests/new?merge_request[source_branch]=${branch_name}",
    },
    disable_insert_on_commit = true,
    use_per_project_settings = true,
    remember_settings = true,
    auto_refresh = true,
    sort_branches = "-committerdate",
    kind = "tab",
    disable_line_numbers = true,
    -- The time after which an output console is shown for slow running commands
    console_timeout = 2000,
    -- Automatically show console if a command takes more than console_timeout milliseconds
    auto_show_console = true,
    notification_icon = "󰊢",
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
      verify_commit = vim.fn.executable("gpg") == 1,
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
    tag_editor = {
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
    integrations = {
      telescope = nil,
      diffview = nil,
      fzf_lua = nil,
    },
    sections = {
      sequencer = {
        folded = false,
        hidden = false,
      },
      untracked = {
        folded = false,
        hidden = false,
      },
      unstaged = {
        folded = false,
        hidden = false,
      },
      staged = {
        folded = false,
        hidden = false,
      },
      stashes = {
        folded = true,
        hidden = false,
      },
      unpulled_upstream = {
        folded = true,
        hidden = false,
      },
      unmerged_upstream = {
        folded = false,
        hidden = false,
      },
      unpulled_pushRemote = {
        folded = true,
        hidden = false,
      },
      unmerged_pushRemote = {
        folded = false,
        hidden = false,
      },
      recent = {
        folded = true,
        hidden = false,
      },
      rebase = {
        folded = true,
        hidden = false,
      },
    },
    ignored_settings = {
      "NeogitPushPopup--force-with-lease",
      "NeogitPushPopup--force",
      "NeogitPullPopup--rebase",
      "NeogitLogPopup--",
      "NeogitCommitPopup--allow-empty",
      "NeogitRevertPopup--no-edit", -- TODO: Fix incompatible switches with default enables
    },
    mappings = {
      finder = {
        ["<cr>"] = "Select",
        ["<c-c>"] = "Close",
        ["<esc>"] = "Close",
        ["<c-n>"] = "Next",
        ["<c-p>"] = "Previous",
        ["<down>"] = "Next",
        ["<up>"] = "Previous",
        ["<tab>"] = "MultiselectToggleNext",
        ["<s-tab>"] = "MultiselectTogglePrevious",
        ["<c-j>"] = "NOP",
      },
      status = {
        ["q"] = "Close",
        ["I"] = "InitRepo",
        ["1"] = "Depth1",
        ["2"] = "Depth2",
        ["3"] = "Depth3",
        ["4"] = "Depth4",
        ["<tab>"] = "Toggle",
        ["x"] = "Discard",
        ["s"] = "Stage",
        ["S"] = "StageUnstaged",
        ["<c-s>"] = "StageAll",
        ["u"] = "Unstage",
        ["U"] = "UnstageStaged",
        ["d"] = "DiffAtFile",
        ["$"] = "CommandHistory",
        ["#"] = "Console",
        ["<c-r>"] = "RefreshBuffer",
        ["<enter>"] = "GoToFile",
        ["<c-v>"] = "VSplitOpen",
        ["<c-x>"] = "SplitOpen",
        ["<c-t>"] = "TabOpen",
        ["?"] = "HelpPopup",
        ["D"] = "DiffPopup",
        ["p"] = "PullPopup",
        ["r"] = "RebasePopup",
        ["m"] = "MergePopup",
        ["P"] = "PushPopup",
        ["c"] = "CommitPopup",
        ["i"] = "IgnorePopup",
        ["t"] = "TagPopup",
        ["l"] = "LogPopup",
        ["v"] = "RevertPopup",
        ["Z"] = "StashPopup",
        ["A"] = "CherryPickPopup",
        ["b"] = "BranchPopup",
        ["f"] = "FetchPopup",
        ["X"] = "ResetPopup",
        ["M"] = "RemotePopup",
        ["{"] = "GoToPreviousHunkHeader",
        ["}"] = "GoToNextHunkHeader",
      },
    },
  }
end

M.values = M.get_default_values()

---Validates the config
---@return { [string]: string } all error messages emitted during validation
function M.validate_config()
  local config = M.values

  ---@type { [string]: string }
  local errors = {}
  local function err(value, msg)
    errors[value] = msg
  end

  ---Checks if a variable is the correct, type if not it calls err with an error string
  ---@param value any
  ---@param name string
  ---@param expected_types type | type[]
  local function validate_type(value, name, expected_types)
    if type(expected_types) == "table" then
      if not vim.tbl_contains(expected_types, type(value)) then
        err(
          name,
          string.format(
            "Expected `%s` to be one of types '%s', got '%s'",
            name,
            table.concat(expected_types, ", "),
            type(value)
          )
        )
        return false
      end
      return true
    end

    if type(value) ~= expected_types then
      err(
        name,
        string.format("Expected `%s` to be of type '%s', got '%s'", name, expected_types, type(value))
      )
      return false
    end
    return true
  end

  -- More complex validation functions go below
  local function validate_kind(val, name)
    if
      validate_type(val, name, "string")
      and not vim.tbl_contains(
        { "split", "vsplit", "split_above", "tab", "floating", "replace", "auto" },
        val
      )
    then
      err(
        name,
        string.format(
          "Expected `%s` to be one of 'split', 'vsplit', 'split_above', 'tab', 'floating', 'replace' or 'auto', got '%s'",
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
      tbl_name = string.format("signs.%s", tbl_name)
      if type(tbl) ~= "table" then
        err(tbl_name, string.format("Expected `%s` to be of type 'table'!", tbl_name))
      else
        if #tbl ~= 2 then
          err(
            tbl_name,
            string.format("Expected for `%s` to be %s elements, it had %s elements!", tbl_name, #tbl, #tbl)
          )
        elseif type(tbl[1]) ~= "string" then
          err(
            tbl_name,
            string.format(
              "Expected element one of `%s` to be of type 'string', it was of type '%s'",
              tbl_name,
              tbl[1],
              type(tbl[1])
            )
          )
        elseif type(tbl[2]) ~= "string" then
          err(
            tbl_name,
            string.format(
              "Expected element two of `%s` to be of type 'string', it was of type '%s'",
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

  local function validate_trinary_auto(value, name)
    local err_msg =
      string.format("Expected '%s' to be either a string with value 'auto' or a boolean value", name)
    if type(value) == "string" then
      if value ~= "auto" then
        err(name, err_msg)
      end
    elseif type(value) ~= "boolean" then
      err(name, err_msg)
    end
  end

  local function validate_integrations()
    local valid_integrations = { "diffview", "telescope", "fzf_lua" }
    if not validate_type(config.integrations, "integrations", "table") or #config.integrations == 0 then
      return
    end
    for integration_name, _ in pairs(config.integrations) do
      if not vim.tbl_contains(valid_integrations, integration_name) then
        err(
          "valid_integrations." .. integration_name,
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
      validate_type(section.hidden, string.format("section.%s.hidden", section_name), "boolean")
    end
  end

  local function validate_ignored_settings()
    if not validate_type(config.ignored_settings, "ignored_settings", "table") then
      return
    end

    for _, setting in ipairs(config.ignored_settings) do
      if validate_type(setting, "ignored_settings." .. vim.inspect(setting), "string") then
        local match_pattern = ".+%-%-.?"
        if not string.match(setting, match_pattern) then
          err(
            "ignored_settings",
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
    local valid_finder_commands = {
      false,
    }

    for _, cmd in pairs(M.get_default_values().mappings.finder) do
      table.insert(valid_finder_commands, cmd)
    end

    local function validate_finder_map(command, key)
      if
        not validate_type(key, string.format("mappings.finder -> %s", vim.inspect(key)), "string")
        or not validate_type(
          command,
          string.format("mappings.finder[%s]", vim.inspect(command)),
          { "string", "boolean" }
        )
      then
        return
      end

      if not vim.tbl_contains(valid_finder_commands, command) then
        local valid_finder_commands = util.map(valid_finder_commands, function(command)
          return vim.inspect(command)
        end)

        err(
          string.format("mappings.finder[%s] -> %s", vim.inspect(key), vim.inspect(command)),

          string.format(
            "Expected a valid finder command, got %s. Valid finder commands: { %s }",
            vim.inspect(command),
            table.concat(valid_finder_commands, ", ")
          )
        )
      end
    end

    if validate_type(config.mappings.finder, "mappings.finder", "table") then
      for key, command in pairs(config.mappings.finder) do
        validate_finder_map(command, key)
      end
    end

    -- Validate mappings.status
    local valid_status_commands = {
      false,
    }

    for _, cmd in pairs(M.get_default_values().mappings.status) do
      table.insert(valid_status_commands, cmd)
    end

    if validate_type(config.mappings.status, "mappings.status", "table") then
      for key, command in pairs(config.mappings.status) do
        if
          validate_type(key, "mappings.status -> " .. vim.inspect(key), "string")
          and validate_type(
            command,
            string.format("mappings.status['%s']", key),
            { "string", "boolean", "function" }
          )
        then
          if type(command) == "string" and not vim.tbl_contains(valid_status_commands, command) then
            local valid_status_commands = util.map(valid_status_commands, function(command)
              return vim.inspect(command)
            end)

            err(
              string.format("mappings.status['%s']", key),
              string.format(
                "Expected a valid status command, got '%s'. Valid status commands: { %s }",
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
    validate_type(config.telescope_sorter, "telescope_sorter", "function")
    validate_type(config.use_per_project_settings, "use_per_project_settings", "boolean")
    validate_type(config.remember_settings, "remember_settings", "boolean")
    validate_type(config.auto_refresh, "auto_refresh", "boolean")
    validate_type(config.sort_branches, "sort_branches", "string")
    validate_type(config.notification_icon, "notification_icon", "string")
    validate_type(config.console_timeout, "console_timeout", "number")
    validate_kind(config.kind, "kind")
    validate_type(config.disable_line_numbers, "disable_line_numbers", "boolean")
    validate_type(config.auto_show_console, "auto_show_console", "boolean")
    if validate_type(config.status, "status", "table") then
      validate_type(config.status.recent_commit_count, "status.recent_commit_count", "number")
    end
    validate_signs()
    validate_trinary_auto(config.disable_insert_on_commit, "disable_insert_on_commit")
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

  return errors
end

---@param name string
---@return boolean
function M.check_integration(name)
  local logger = require("neogit.logger")
  local enabled = M.values.integrations[name]

  if enabled == nil or enabled == "auto" then
    local success, _ = pcall(require, name)
    logger.fmt_info("[CONFIG] Found auto integration '%s = %s'", name, success)
    return success
  end

  logger.fmt_info("[CONFIG] Found explicit integration '%s' = %s", name, enabled)
  return enabled
end

function M.setup(opts)
  if opts ~= nil then
    M.values = vim.tbl_deep_extend("force", M.values, opts)
  end

  local config_errs = M.validate_config()
  if vim.tbl_count(config_errs) > 0 then
    local header = "====Neogit Configuration Errors===="
    local header_message = {
      "Neogit has NOT been setup!",
      "You have a misconfiguration in your Neogit setup!",
      'Validate that your configuration passed to `require("neogit").setup()` is valid!',
    }
    local header_sep = ""
    for _ = 0, string.len(header), 1 do
      header_sep = header_sep .. "-"
    end

    local config_errs_message = {}
    for config_key, err in pairs(config_errs) do
      table.insert(config_errs_message, string.format("Config value: `%s` had error -> %s", config_key, err))
    end
    error(
      string.format(
        "\n%s\n%s\n%s\n%s",
        header,
        table.concat(header_message, "\n"),
        header_sep,
        table.concat(config_errs_message, "\n")
      ),
      vim.log.levels.ERROR
    )
  end
end

return M
