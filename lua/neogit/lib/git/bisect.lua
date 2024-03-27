local cli = require("neogit.lib.git.cli")
local logger = require("neogit.logger")

local M = {}

local function fire_bisect_event(data)
  vim.api.nvim_exec_autocmds("User", { pattern = "NeogitBisect", modeline = false, data = data })
end

---@param cmd string
local function bisect(cmd)
  local result = cli.bisect.args(cmd).call()

  if result.code == 0 then
    fire_bisect_event { type = cmd }
  end
end

function M.in_progress()
  local git = require("neogit.lib.git")
  return git.repo:git_path("BISECT_LOG"):exists()
end

function M.is_finished()
  local git = require("neogit.lib.git")
  return git.repo.bisect.finished
end

---@param bad_revision string
---@param good_revision string
---@param args? table
function M.start(bad_revision, good_revision, args)
  local result = cli.bisect.args("start").arg_list(args).args(bad_revision, good_revision).call()

  if result.code == 0 then
    fire_bisect_event { type = "start" }
  end
end

function M.good()
  bisect("good")
end

function M.bad()
  bisect("bad")
end

function M.skip()
  bisect("skip")
end

function M.reset()
  bisect("reset")
end

---@param command string
function M.run(command)
  cli.bisect.args("run", command).call()
end

---@class BisectItem
---@field action string
---@field oid string
---@field subject string
---@field abbreviated_commit string

local function update_bisect_information(state)
  logger.debug("[GIT BISECT] Starting")
  state.bisect = { items = {}, finished = false, current = {} }

  if not M.in_progress() then
    logger.debug("[GIT BISECT] Not in progress")
    return
  end

  logger.debug("[GIT BISECT] In progress")
  local finished
  local git = require("neogit.lib.git")

  for line in git.repo:git_path("BISECT_LOG"):iter() do
    if line:match("^#") and line ~= "" then
      local action, oid, subject = line:match("^# ([^:]+): %[(.+)%] (.+)")

      finished = action == "first bad commit"
      if finished then
        fire_bisect_event { type = "finished", oid = oid }
      end

      ---@type BisectItem
      local item = {
        finished = finished,
        action = action,
        subject = subject,
        oid = oid,
        abbreviated_commit = oid:sub(1, git.log.abbreviated_size()),
      }

      table.insert(state.bisect.items, item)
    end
  end

  local expected = vim.trim(git.repo:git_path("BISECT_EXPECTED_REV"):read())
  state.bisect.current =
    git.log.parse(git.cli.show.format("fuller").args(expected).call_sync({ trim = false }).stdout)[1]

  state.bisect.finished = finished
end

M.register = function(meta)
  meta.update_bisect_information = update_bisect_information
end

return M
