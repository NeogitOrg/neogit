local cli = require("neogit.lib.git.cli")

local M = {}

local function fire_bisect_event(data)
  vim.api.nvim_exec_autocmds("User", { pattern = "NeogitBisect", modeline = false, data = data })
end

function M.in_progress()
  local git = require("neogit.lib.git")
  return git.repo:git_path("BISECT_LOG"):exists()
end

function M.is_finished()
  local git = require("neogit.lib.git")
  return git.repo.state.bisect.finished
end

---@param bad_revision string
---@param good_revision string
---@param args? table
function M.start(bad_revision, good_revision, args)
  local result = cli.bisect.args("start").arg_list(args).args(good_revision, bad_revision).call()

  if result.code == 0 then
    fire_bisect_event({ type = "start" })
  end
end

---@param state string
local function cmd(state)
  local result = cli.bisect.args(state).call()

  if result.code == 0 then
    fire_bisect_event({ type = state })
  end
end

function M.good()
  cmd("good")
end

function M.bad()
  cmd("bad")
end

function M.skip()
  cmd("skip")
end

function M.reset()
  cmd("reset")
end

---@class BisectItem
---@field action string
---@field oid string
---@field subject string
---@field abbreviated_commit string

local function update_bisect_information(state)
  state.bisect = { items = {}, finished = false }

  local finished
  local git = require("neogit.lib.git")
  local bisect_log = git.repo:git_path("BISECT_LOG")

  if bisect_log:exists() then
    for line in bisect_log:iter() do
      if line:match("^#") and line ~= "" then
        local action, oid, subject = line:match("^# ([^:]+): %[(.+)%] (.+)")

        finished = action == "first bad commit"
        if finished then
          fire_bisect_event({ type = "finished", oid = oid })
        end

        ---@type BisectItem
        local item = {
          finished = finished,
          action = action,
          subject = subject,
          oid = oid,
          abbreviated_commit = oid:sub(1, git.log.abbreviated_size())
        }

        table.insert(state.bisect.items, item)
      end
    end

    state.bisect.finished = finished
  end
end

M.register = function(meta)
  meta.update_bisect_information = update_bisect_information
end

return M
