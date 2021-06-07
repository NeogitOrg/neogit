local popup = require("neogit.lib.popup")
local status = require 'neogit.status'
local cli = require("neogit.lib.git.cli")
local input = require("neogit.lib.input")
local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")
local a = require 'plenary.async_lib'
local async, await, scheduler, void, wrap, uv = a.async, a.await, a.scheduler, a.void, a.wrap, a.uv
local split = require('neogit.lib.util').split
local uv_utils = require 'neogit.lib.uv'

local function get_commit_file()
  return cli.git_dir_path_sync() .. '/' .. 'NEOGIT_COMMIT_EDITMSG'
end

local get_commit_message = wrap(function (content, cb)
  Buffer.create {
    name = get_commit_file(),
    filetype = "gitcommit",
    buftype = "",
    modifiable = true,
    readonly = false,
    initialize = function(buffer)
      buffer:set_lines(0, -1, false, content)
      vim.cmd("silent w!")

      local written = false

      _G.__NEOGIT_COMMIT_BUFFER_CB_WRITE = function()
        written = true
      end

      _G.__NEOGIT_COMMIT_BUFFER_CB_UNLOAD = function()
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

        -- cleanup global temporary functions
        _G.__NEOGIT_COMMIT_BUFFER_CB_WRITE = nil
        _G.__NEOGIT_COMMIT_BUFFER_CB_UNLOAD = nil
      end

      buffer:define_autocmd("BufWritePost", "lua __NEOGIT_COMMIT_BUFFER_CB_WRITE()")
      buffer:define_autocmd("BufUnload", "lua __NEOGIT_COMMIT_BUFFER_CB_UNLOAD()")

      buffer.mmanager.mappings["q"] = function()
        buffer:close(true)
      end
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
    table.insert(output, "# Please enter the commit message for your changes. Lines starting")
    table.insert(output, "# with '#' will be ignored, and an empty message aborts the commit.")

    local status_output = await(cli.status.call())
    status_output = vim.split(status_output, '\n')

    for _, line in pairs(status_output) do
      if not vim.startswith(line, "  (") then
        table.insert(output, "# " .. line)
      end
    end
  end

  await(scheduler())
  await(get_commit_message(output))
end)

local function create()
  popup.create(
    "NeogitCommitPopup",
    {
      {
        key = "a",
        description = "Stage all modified and deleted files",
        cli = "all",
        enabled = false
      },
      {
        key = "e",
        description = "Allow empty commit",
        cli = "allow-empty",
        enabled = false
      },
      {
        key = "v",
        description = "Show diff of changes to be committed",
        cli = "verbose",
        enabled = false
      },
      {
        key = "h",
        description = "Disable hooks",
        cli = "no-verify",
        enabled = false
      },
      {
        key = "s",
        description = "Add Signed-off-by line",
        cli = "signoff",
        enabled = false
      },
      {
        key = "S",
        description = "Do not sign this commit",
        cli = "no-gpg-sign",
        enabled = false
      },
      {
        key = "R",
        description = "Claim authorship and reset author date",
        cli = "reset-author",
        enabled = false
      },
    },
    {
      {
        key = "A",
        description = "Override the author",
        cli = "author",
        value = ""
      },
      {
        key = "S",
        description = "Sign using gpg",
        cli = "gpg-sign",
        value = ""
      },
      {
        key = "C",
        description = "Reuse commit message",
        cli = "reuse-message",
        value = ""
      },
    },
    {
      {
        {
          key = "c",
          description = "Commit",
          callback = void(async(function (popup)
            await(scheduler())
            local commit_file = get_commit_file()
            local _, data = await(uv_utils.read_file(commit_file))
            local skip_gen = data ~= nil
            data = data or ''
            -- we need \r? to support windows
            data = split(data, '\r?\n')
            await(prompt_commit_message(data, skip_gen))
            local _, code = await(
              cli.commit.commit_message_file(commit_file).args(unpack(popup.get_arguments())).call()
            )
            if code == 0 then
              await(uv.fs_unlink(commit_file))
              await(status.refresh(true))
            end
          end))
        },
      },
      {
        {
          key = "e",
          description = "Extend",
          callback = void(async(function ()
            await(scheduler())
            local commit_file = get_commit_file()
            local _, code = await(cli.commit.no_edit.amend.call())
            if code == 0 then
              await(uv.fs_unlink(commit_file))
              await(status.refresh(true))
            end
          end))
        },
        {
          key = "w",
          description = "Reword",
          callback = void(async(function ()
            await(scheduler())
            local commit_file = get_commit_file()
            local msg = await(cli.log.max_count(1).pretty('%B').call())
            msg = vim.split(msg, '\n')

            await(prompt_commit_message(msg))
            local _, code = await(cli.commit.commit_message_file(commit_file).amend.only.call())
            if code == 0 then
              await(uv.fs_unlink(commit_file))
              await(status.refresh(true))
            end
          end))
        },
        {
          key = "a",
          description = "Amend",
          callback = void(async(function ()
            local msg = await(cli.log.max_count(1).pretty('%B').call())
            msg = vim.split(msg, '\n')

            await(scheduler())
            await(prompt_commit_message(msg))
            local _, code = await(cli.commit.commit_message_file(get_commit_file()).amend.call())
            if code == 0 then
              await(uv.fs_unlink(get_commit_file()))
              await(status.refresh(true))
            end
          end))
        },
      },
      {
        {
          key = "f",
          description = "Fixup",
          callback = function() end
        },
        {
          key = "s",
          description = "Squash",
          callback = function() end
        },
        {
          key = "A",
          description = "Augment",
          callback = function() end
        },
      },
      {
        {
          key = "F",
          description = "Instant Fixup",
          callback = function() end
        },
        {
          key = "S",
          description = "Instant Squash",
          callback = function() end
        },
      }
    })
end

return {
  create = create
}
