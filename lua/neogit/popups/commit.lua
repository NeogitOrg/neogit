local popup = require("neogit.lib.popup")
local cli = require("neogit.lib.git.cli")
local input = require("neogit.lib.input")
local Buffer = require("neogit.lib.buffer")
local a = require('neogit.async')
local uv = require('neogit.async.uv')
local split = require('neogit.lib.util').split

local find_root = function()
  local base_pwd = vim.fn.getcwd()
  local target = string.byte("/")
  for idx = #base_pwd, 1, -1 do
    if base_pwd:byte(idx) == target then
      local gitpath = base_pwd:sub(1, idx) .. ".git"
      if vim.fn.isdirectory(gitpath) > 0 then
        return gitpath
      end
    end
  end
  return ".git"
end

local commit_file = function() return find_root() .. '/NEOGIT_COMMIT_EDITMSG' end

local get_commit_message = a.wrap(function (content, cb)

  Buffer.create {
    name = commit_file(),
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
          if input.get_confirmation("Are you sure you want to commit?") then
            vim.cmd [[
              silent g/^#/d
              silent w!
            ]]
            cb()
          else
            vim.cmd [[
              silent 1,$d
              silent w!
            ]]
          end
        end
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
end)

local prompt_commit_message = a.sync(function (msg)
  local output = {}

  if msg and #msg > 0 then
    for _, line in ipairs(msg) do
      table.insert(output, line)
    end
  else
    table.insert(output, "")
  end

  table.insert(output, "# Please enter the commit message for your changes. Lines starting")
  table.insert(output, "# with '#' will be ignored, and an empty message aborts the commit.")

  local status_output = a.wait(cli.status.call())
  status_output = vim.split(status_output, '\n')

  for _, line in pairs(status_output) do
    if not vim.startswith(line, "  (") then
      table.insert(output, "# " .. line)
    end
  end

  a.wait_for_textlock()
  a.wait(get_commit_message(output))
end)

local function create()
  local COMMIT_FILE = commit_file()
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
          callback = function(popup)
            a.dispatch(function ()
              local data = a.wait(uv.read_file(COMMIT_FILE))
              local old_content = split(data or '', '\n')
              a.wait(prompt_commit_message(old_content))
              local _, code = a.wait(cli.commit.commit_message_file(COMMIT_FILE).args(unpack(popup.get_arguments())).call())
              if code == 0 then
                a.wait(uv.fs_unlink(COMMIT_FILE))
                __NeogitStatusRefresh(true)
              end
            end)
          end
        },
      },
      {
        {
          key = "e",
          description = "Extend",
          callback = function(popup)
            a.dispatch(function ()
              local _, code = a.wait(cli.commit.no_edit.amend.call())
              if code == 0 then
                a.wait(uv.fs_unlink(COMMIT_FILE))
                __NeogitStatusRefresh(true)
              end
            end)
          end
        },
        {
          key = "w",
          description = "Reword",
          callback = function()
            a.dispatch(function ()
              local msg = a.wait(cli.log.max_count(1).pretty('%B').call())
              msg = vim.split(msg, '\n')

              a.wait(prompt_commit_message(msg))
              local _, code = a.wait(cli.commit.commit_message_file(COMMIT_FILE).amend.only.call())
              if code == 0 then
                a.wait(uv.fs_unlink(COMMIT_FILE))
                __NeogitStatusRefresh(true)
              end
            end)
          end
        },
        {
          key = "a",
          description = "Amend",
          callback = function(popup)
            a.dispatch(function ()
              local msg = a.wait(cli.log.max_count(1).pretty('%B').call())
              msg = vim.split(msg, '\n')

              a.wait(prompt_commit_message(msg))
              local _, code = a.wait(cli.commit.commit_message_file(COMMIT_FILE).amend.call())
              if code == 0 then
                a.wait(uv.fs_unlink(COMMIT_FILE))
                __NeogitStatusRefresh(true)
              end
            end)
          end
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
