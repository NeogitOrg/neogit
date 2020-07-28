local Buffer = require("neogit.lib.buffer")
local Git = require("neogit.lib.git")

local GitCommandHistory = {}
GitCommandHistory.__index = GitCommandHistory

function GitCommandHistory:new()
  local this = {
    buffer = nil,
    open = false
  }

  setmetatable(this, self)

  return this
end

function GitCommandHistory:show()
  if self.open then
    return
  end

  self.open = true
  self.buffer = Buffer.create {
    name = "NeogitGitCommandHistory",
    filetype = "NeogitGitCommandHistory",
    initialize = function(buffer)
      local lines = {}
      local folds = {}
      local mappings = buffer.mmanager.mappings

      mappings["tab"] = ":silent! norm za<CR>"

      for _,cmd in pairs(Git.cli.history) do
        table.insert(lines, string.format("% 3d %s", cmd.code, cmd.cmd))
        if #cmd.stderr ~= 0 then
          local first = #lines
          for _,line in pairs(cmd.stderr) do
            table.insert(lines, string.format("  | %s", line))
          end
          local last = #lines
          table.insert(folds, { first, last })
        elseif #cmd.stdout ~= 0 then
          local first = #lines
          for _,line in pairs(cmd.stdout) do
            table.insert(lines, string.format("  | %s", line))
          end
          local last = #lines
          table.insert(folds, { first, last })
        end
      end

      buffer:set_lines(0, -1, false, lines)

      for _,f in pairs(folds) do
        buffer:create_fold(f[1], f[2])
      end

      buffer:move_cursor(-1)
    end
  }
end

return GitCommandHistory
