local popup = require("neogit.lib.popup")
local notif = require("neogit.lib.notification")
local status = require 'neogit.status'
local cli = require("neogit.lib.git.cli")
local input = require("neogit.lib.input")
local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local a = require 'plenary.async_lib'
local async, await, scheduler, wrap, uv = a.async, a.await, a.scheduler, a.wrap, a.uv
local split = require('neogit.lib.util').split
local uv_utils = require 'neogit.lib.uv'

local M = {}

local function get_commit_file()
  return cli.git_dir_path_sync() .. '/' .. 'NEOGIT_COMMIT_EDITMSG'
end

-- selene: allow(global_usage)
local get_commit_message = wrap(function (content, cb)
  local written = false
  Buffer.create {
    name = get_commit_file(),
    filetype = "gitcommit",
    buftype = "",
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
    end
  }
end, 2)

-- If skip_gen is true we don't generate the massive git comment.
-- This flag should be true when the file already exists
local prompt_commit_message = async(function (msg, skip_gen)
  local output = {}

  if msg and #msg > 0 then
    for _, line in ipairs(msg) do
      table.insert(output, line)
    end
  elseif not skip_gen then
    table.insert(output, "")
  end

  if not skip_gen then
    local lines = await(cli.commit.dry_run.call())
    for _, line in ipairs(lines) do
      table.insert(output, "# " .. line)
    end
  end

  await(scheduler())
  await(get_commit_message(output))
end)

local do_commit = async(function(data, cmd, skip_gen)
  await(scheduler())
  local commit_file = get_commit_file()
  if data then
    await(prompt_commit_message(data, skip_gen))
  end
  await(scheduler())
  local notification = notif.create("Committing...", { delay = 9999 })
  local _, code = await(cmd.call())
  await(scheduler())
  notification:delete()
  notif.create("Successfully committed!")
  if code == 0 then
    await(uv.fs_unlink(commit_file))
    await(status.refresh(true))
  end
end)

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
      await(scheduler())
      local commit_file = get_commit_file()
      local _, data = await(uv_utils.read_file(commit_file))
      local skip_gen = data ~= nil
      data = data or ''
      -- we need \r? to support windows
      data = split(data, '\r?\n')
      await(do_commit(data, cli.commit.commit_message_file(commit_file).args(unpack(popup:get_arguments())), skip_gen))
    end)
    :action("e", "Extend", function()
      await(do_commit(nil, cli.commit.no_edit.amend))
    end)
    :action("w", "Reword", function()
      await(scheduler())
      local commit_file = get_commit_file()
      local msg = await(cli.log.max_count(1).pretty('%B').call())

      await(do_commit(msg, cli.commit.commit_message_file(commit_file).amend.only))
    end)
    :action("a", "Amend", function()
      await(scheduler())
      local commit_file = get_commit_file()
      local msg = await(cli.log.max_count(1).pretty('%B').call())

      await(do_commit(msg, cli.commit.commit_message_file(commit_file).amend))
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
