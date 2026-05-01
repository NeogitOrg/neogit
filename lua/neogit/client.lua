local RPC = require("neogit.lib.rpc")
local logger = require("neogit.logger")
local config = require("neogit.config")
local git = require("neogit.lib.git")
local Path = require("neogit.lib.path")

local fn = vim.fn
local fmt = string.format

local M = {}

function M.get_nvim_remote_editor(show_diff)
  local neogit_path = debug.getinfo(1, "S").source:sub(2, -#"lua/neogit/client.lua" - 2)
  local nvim_path = fn.shellescape(vim.v.progpath)

  logger.debug("[CLIENT] Neogit path: " .. neogit_path)
  logger.debug("[CLIENT] Neovim path: " .. nvim_path)
  local runtimepath_cmd = fn.shellescape(fmt("set runtimepath^=%s", fn.fnameescape(tostring(neogit_path))))
  local lua_cmd =
    fn.shellescape("lua require('neogit.client').client({ show_diff = " .. tostring(show_diff) .. " })")

  local shell_cmd = {
    nvim_path,
    "--headless",
    "--clean",
    "--noplugin",
    "-n",
    "-R",
    "-c",
    runtimepath_cmd,
    "-c",
    lua_cmd,
  }

  return table.concat(shell_cmd, " ")
end

function M.get_envs_git_editor(show_diff)
  local nvim_cmd = M.get_nvim_remote_editor(show_diff)

  local env = {
    GIT_SEQUENCE_EDITOR = nvim_cmd,
    GIT_EDITOR = nvim_cmd,
  }

  if os.getenv("NEOGIT_DEBUG") then
    env.NEOGIT_LOG_LEVEL = "debug"
    env.NEOGIT_LOG_FILE = "true"
    env.NEOGIT_DEBUG = true
  end

  return env
end

--- Entry point for the headless client.
--- Starts a server and connects to the parent process rpc, opening an editor
function M.client(opts)
  local nvim_server = vim.env.NVIM
  if not nvim_server then
    error("NVIM server address not set")
  end

  local file_target = fn.fnamemodify(fn.argv()[1], ":p")
  logger.debug(("[CLIENT] File target: %s"):format(file_target))

  local client = fn.serverstart()
  logger.debug(("[CLIENT] Client address: %s"):format(client))

  local lua_cmd = fmt('lua require("neogit.client").editor(%q, %q, %s)', file_target, client, opts.show_diff)
  local rpc_server = RPC.create_connection(nvim_server)
  rpc_server:send_cmd(lua_cmd)
end

--- Invoked by the `client` and starts the appropriate file editor
---@param target string Filename to open
---@param client string Address returned from vim.fn.serverstart()
---@param show_diff boolean
function M.editor(target, client, show_diff)
  logger.debug(("[CLIENT] Invoked editor with target: %s, from: %s"):format(target, client))
  require("neogit.process").hide_preview_buffers()

  local rpc_client = RPC.create_connection(client)

  ---on_unload callback when closing editor
  ---@param status integer Status code to close remote nvim instance with. 0 for success, 1 for failure
  local function send_client_quit(status)
    if status == 0 then
      rpc_client:send_cmd_async("qall")
    elseif status == 1 then
      rpc_client:send_cmd_async("cq")
    end

    rpc_client:disconnect()
  end

  local kind
  if target:find("COMMIT_EDITMSG$") then
    kind = config.values.commit_editor.kind
  elseif target:find("MERGE_MSG$") then
    kind = config.values.merge_editor.kind
  elseif target:find("TAG_EDITMSG$") or target:find("EDIT_DESCRIPTION$") then
    kind = "popup"
  elseif target:find("git%-rebase%-todo$") then
    kind = config.values.rebase_editor.kind
  else
    kind = "auto"
  end

  local editor
  if target:find("git%-rebase%-todo$") then
    editor = require("neogit.buffers.rebase_editor")
  else
    editor = require("neogit.buffers.editor")
  end

  editor.new(target, send_client_quit, show_diff):open(kind)
end

---@class NotifyMsg
---@field setup string|nil Message to show before running
---@field success string|nil Message to show when successful
---@field fail string|nil Message to show when failed

---@class WrapOpts
---@field autocmd string
---@field msg NotifyMsg
---@field show_diff boolean?
---@field interactive boolean?

---@param cmd any
---@param opts WrapOpts
---@return integer code of `cmd`
function M.wrap(cmd, opts)
  local notification = require("neogit.lib.notification")
  local a = require("neogit.lib.async")

  a.util.scheduler()

  if opts.msg.setup then
    notification.info(opts.msg.setup)
  end

  -- When retrying after a failed passphrase, preserve the commit message the
  -- user already wrote.  git overwrites COMMIT_EDITMSG with a fresh template
  -- before calling GIT_EDITOR on every invocation, so we save the file to a
  -- temp path on the first retry and replace GIT_EDITOR with a plain `cp`
  -- that restores it — skipping the editor UI entirely.
  local on_retry
  if opts.interactive then
    local tmp_message_file = nil
    on_retry = function(proc)
      if not (proc.env and proc.env.GIT_EDITOR) then
        return
      end

      if not tmp_message_file then
        local editmsg_path = Path.new(git.repo.worktree_git_dir .. "/COMMIT_EDITMSG")
        if editmsg_path:exists() then
          local content = editmsg_path:read()
          if content then
            local tmpfile = Path.new(vim.fn.tempname())
            if tmpfile:write(content, "w") then
              tmp_message_file = tmpfile:absolute()
            end
          end
        end
      end

      if tmp_message_file then
        local escaped = vim.fn.shellescape(tmp_message_file)
        local copy_cmd = vim.fn.has("win32") == 1 and ("copy /y " .. escaped) or ("cp " .. escaped)
        proc.env.GIT_EDITOR = copy_cmd
        proc.env.GIT_SEQUENCE_EDITOR = copy_cmd
      end
    end
  end

  logger.debug("[CLIENT] Calling editor command")
  local result = cmd.env(M.get_envs_git_editor(opts.show_diff)).call {
    pty = opts.interactive,
    on_retry = on_retry,
  }

  a.util.scheduler()
  logger.debug("[CLIENT] DONE editor command")

  if result:success() then
    if opts.msg.success then
      notification.info(opts.msg.success, { dismiss = true })
    end
    vim.api.nvim_exec_autocmds("User", { pattern = opts.autocmd, modeline = false })
  else
    if opts.msg.fail then
      notification.warn(opts.msg.fail, { dismiss = true })
    end
  end

  return result.code
end

return M
