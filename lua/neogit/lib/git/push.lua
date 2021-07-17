local a = require 'plenary.async_lib'
local async, await = a.async, a.await
local cli = require('neogit.lib.git.cli')
local util = require('neogit.lib.util')

local M = {}

M.push_interactive = a.wrap(function(remote, branch, cb)
  -- from: https://stackoverflow.com/questions/48948630/lua-ansi-escapes-pattern
  local ansi_escape_sequence_pattern = "[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]"
  local cmd = "git push " .. remote .. " " .. branch
  local stdout = {}
  local raw_stdout = {}
  local chan
  local skip_count = 0

  local function handle_line(line)
    if vim.startswith(line, "Username for ") then
      local prompt = line:match("(.*:):.*")
      local value = vim.fn.input {
        prompt = prompt .. " ",
        cancelreturn = "__CANCEL__"
      }
      if value ~= "__CANCEL__" then
        vim.fn.chansend(chan, value .. "\n")
      else
        vim.fn.chanclose(chan)
      end
    elseif vim.startswith(line, "Password for ") then
      local prompt = line:match("(.*:).*")
      local value = vim.fn.inputsecret {
        prompt = prompt .. " ",
        cancelreturn = "__CANCEL__"
      }
      if value ~= "__CANCEL__" then
        vim.fn.chansend(chan, value .. "\n")
      else
        vim.fn.chanclose(chan)
      end
    else
      return false
    end

    return true
  end

  local started_at = os.clock()
  chan = vim.fn.jobstart(vim.fn.has('win32') == 1 and { "cmd", "/C", cmd } or cmd, {
    pty = true,
    on_stdout = function(_, data)
      table.insert(raw_stdout, data)
      local is_end = #data == 1 and data[1] == ""
      if is_end then
        return
      end
      local data = table.concat(data, "")
      local data = data:gsub(ansi_escape_sequence_pattern, "")
      table.insert(stdout, data)
      local lines = vim.split(data, "\r?[\r\n]")

      for i=1,#lines do
        if lines[i] ~= "" then
          if skip_count > 0 then
            skip_count = skip_count - 1
          else
            handle_line(lines[i])
          end
        end
      end
    end,
    on_exit = function(_, code)
      cli.insert {
        cmd = cmd,
        raw_cmd = cmd,
        stdout = stdout,
        stderr = stdout,
        code = code,
        time = (os.clock() - started_at) * 1000
      }

      cb({
        code = code,
        stdout = stdout
      })
    end,
  })
end, 3)

local update_unmerged = async(function (state)
  if not state.upstream.branch then return end

  local result = await(
    cli.log.oneline.for_range('@{upstream}..').show_popup(false).call())

  state.unmerged.files = util.map(result, function (x) 
    return { name = x } 
  end)
end)

function M.register(meta)
  meta.update_unmerged = update_unmerged
end

return M
