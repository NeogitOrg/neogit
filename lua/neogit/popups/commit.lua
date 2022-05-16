local popup = require("neogit.lib.popup")
local notif = require("neogit.lib.notification")
local status = require 'neogit.status'
local cli = require("neogit.lib.git.cli")
local input = require("neogit.lib.input")
local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local a = require 'plenary.async'
local split = require('neogit.lib.util').split
local uv_utils = require 'neogit.lib.uv'

local M = {}

local function get_commit_file()
  return cli.git_dir_path_sync() .. '/' .. 'NEOGIT_COMMIT_EDITMSG'
end

-- selene: allow(global_usage)
local get_commit_message = a.wrap(function (content, cb)
  local written = false
  Buffer.create {
    name = get_commit_file(),
    filetype = "NeogitCommitMessage",
    buftype = "",
    kind = config.values.commit_popup.kind,
    modifiable = true,
    readonly = false,
    autocmds = {
      ["BufWritePost"] = function()
        written = true
      end,
      ["BufUnload"] = function()
        if written then
          if config.values.disable_commit_confirmation or
            input.get_confirmation("Are you sure you want to commit?") then
            vim.cmd [[
              silent g/^#/d
              silent w!
            ]]
            cb()
          end
        end
      end,
    },
    mappings = {
      n = {
        ["q"] = function(buffer)
          buffer:close(true)
        end
      }
    },
    initialize = function(buffer)
      buffer:set_lines(0, -1, false, content)
      if not config.values.disable_insert_on_commit then
        vim.cmd(":startinsert")
      end
    end
  }
end, 2)

-- If skip_gen is true we don't generate the massive git comment.
-- This flag should be true when the file already exists
local function prompt_commit_message(args, msg, skip_gen)
  local msg_template_path = cli.config.get("commit.template").show_popup(false).call()[1]
  local output = {}

  if msg and #msg > 0 then
    for _, line in ipairs(msg) do
      table.insert(output, line)
    end
  elseif not skip_gen and not msg_template_path then
    table.insert(output, "")
  end

  if not skip_gen then
    if msg_template_path then
      a.util.scheduler()
      local expanded_path = vim.fn.glob(msg_template_path)
      if expanded_path == "" then
        return
      end
      local msg_template = uv_utils.read_file_sync(expanded_path)
      for _, line in pairs(msg_template) do
        table.insert(output, line)
      end
      table.insert(output, "")
    end
    local lines = cli.commit.dry_run.args(unpack(args)).call()
    for _, line in ipairs(lines) do
      table.insert(output, "# " .. line)
    end
  end

  a.util.scheduler()
  get_commit_message(output)
end

local function do_commit(popup, data, cmd, skip_gen)
  a.util.scheduler()
  local commit_file = get_commit_file()
  if data then
    prompt_commit_message(popup:get_arguments(), data, skip_gen)
  end
  a.util.scheduler()
  local notification = notif.create("Committing...", vim.log.levels.INFO, 9999)
  local result = cli.interactive_git_cmd(cmd)
  a.util.scheduler()
  if notification then
    notification:delete()
  end
  notif.create("Successfully committed!")
  if result.code == 0 then
    a.uv.fs_unlink(commit_file)
    status.refresh(true)
    vim.cmd([[do <nomodeline> User NeogitCommitComplete]])
  end
end

function M.create()
  local p = popup.builder()
    :name("NeogitCommitPopup")
    :switch("a", "all", "Stage all modified and deleted files", false)
    :switch("e", "allow-empty", "Allow empty commit", false)
    :switch("v", "verbose", "Show diff of changes to be committed", false)
    :switch("h", "no-verify", "Disable hooks", false)
    :switch("s", "signoff", "Add Signed-off-by line", false)
    :switch("S", "no-gpg-sign", "Do not sign this commit", false)
    :switch("R", "reset-author", "Claim authorship and reset author date", false)
    :option("A", "author", "", "Override the author")
    :option("S", "gpg-sign", "", "Sign using gpg")
    :option("C", "reuse-message", "", "Reuse commit message")
    :action("c", "Commit", function(popup)
      a.util.scheduler()
      local commit_file = get_commit_file()
      local _, data = uv_utils.read_file(commit_file)
      local skip_gen = data ~= nil
      data = data or ''
      -- we need \r? to support windows
      data = split(data, '\r?\n')
      do_commit(popup, data, tostring(cli.commit.commit_message_file(commit_file).args(unpack(popup:get_arguments()))), skip_gen)
    end)
    :action("e", "Extend", function(popup)
      do_commit(popup, nil, tostring(cli.commit.no_edit.amend))
    end)
    :action("w", "Reword", function(popup)
      a.util.scheduler()
      local commit_file = get_commit_file()
      local msg = cli.log.max_count(1).pretty('%B').call()

      do_commit(popup, msg, tostring(cli.commit.commit_message_file(commit_file).amend.only))
    end)
    :action("a", "Amend", function(popup)
      a.util.scheduler()
      local commit_file = get_commit_file()
      local msg = cli.log.max_count(1).pretty('%B').call()

      do_commit(popup, msg, tostring(cli.commit.commit_message_file(commit_file).amend), true)
    end)
    :new_action_group()
    :action("f", "Fixup")
    :action("s", "Squash")
    :action("A", "Augment")
    :new_action_group()
    :action("F", "Instant Fixup")
    :action("S", "Instant Squash")
    :build()

  p:show()

  return p
end

return M
