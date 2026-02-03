local M = {}

local fidget_ok, fidget_progress = pcall(require, "fidget.progress")

--- Check if fidget.nvim is available
function M.available()
  return fidget_ok
end

--- @class NeogitFidgetHandle
--- @field handle table The fidget progress handle
--- @field total number Total number of tasks
--- @field completed number Number of completed tasks
--- @field modules table<string, boolean> Track which modules completed
--- @field source string The source of the refresh

--- Create a new progress handle for a refresh operation
--- @param source string The source of the refresh (e.g., "status", "watcher")
--- @param modules string[]|nil List of modules being refreshed (nil = all)
--- @return NeogitFidgetHandle|nil
function M.create(source, modules)
  if not fidget_ok then
    return nil
  end

  local total = modules and #modules or 12 -- 12 total modules by default

  local handle = fidget_progress.handle.create {
    title = "Neogit",
    message = "Starting refresh...",
    lsp_client = { name = "neogit" },
    percentage = 0,
  }

  return {
    handle = handle,
    total = total,
    completed = 0,
    modules = {},
    source = source,
  }
end

--- Report that a module has completed
--- @param progress NeogitFidgetHandle|nil
--- @param module_name string
--- @param duration_ms number
function M.report_module(progress, module_name, duration_ms)
  if not progress or not progress.handle then
    return
  end

  progress.completed = progress.completed + 1
  progress.modules[module_name] = true

  local percentage = math.floor((progress.completed / progress.total) * 100)

  progress.handle:report {
    message = string.format("%s (%dms)", module_name, duration_ms),
    percentage = percentage,
  }
end

--- Mark the refresh as complete
--- @param progress NeogitFidgetHandle|nil
--- @param total_ms number Total duration in milliseconds
function M.finish(progress, total_ms)
  if not progress or not progress.handle then
    return
  end

  progress.handle:report {
    message = string.format("Done (%dms)", total_ms),
    percentage = 100,
  }
  progress.handle:finish()
end

--- Cancel/abort the progress (e.g., on interrupt)
--- @param progress NeogitFidgetHandle|nil
function M.cancel(progress)
  if not progress or not progress.handle then
    return
  end

  progress.handle:report {
    message = "Interrupted",
  }
  progress.handle:cancel()
end

--------------------------------------------------------------------------------
-- Operation Progress Tracking
--------------------------------------------------------------------------------

--- @class NeogitOperationHandle
--- @field handle table The fidget progress handle
--- @field name string Operation name (e.g., "Pushing to origin/main")
--- @field start_time number Start time from vim.uv.now()
--- @field timer userdata uv_timer for elapsed time updates
--- @field finished boolean Whether the operation has completed

--- Format elapsed time for display
--- @param ms number Milliseconds elapsed
--- @return string Formatted time (e.g., "1.2s" or "15s")
local function format_time(ms)
  local seconds = ms / 1000
  if seconds < 10 then
    return string.format("%.1fs", seconds)
  else
    return string.format("%ds", math.floor(seconds))
  end
end

--- Convert operation name from present progressive to past tense
--- @param name string Operation name (e.g., "Pushing to origin/main")
--- @return string Past tense name (e.g., "Pushed to origin/main")
local function to_past_tense(name)
  local patterns = {
    { "^Pushing ", "Pushed " },
    { "^Pulling ", "Pulled " },
    { "^Fetching ", "Fetched " },
    { "^Merging ", "Merged " },
    { "^Rebasing ", "Rebased " },
    { "^Cherry picking ", "Cherry picked " },
    { "^Reverting ", "Reverted " },
    { "^Deleting ", "Deleted " },
    { "^Creating ", "Created " },
    { "^Bisecting ", "Bisected " },
    { "^Cloning ", "Cloned " },
    { "^Stashing ", "Stashed " },
    { "^Applying ", "Applied " },
  }

  for _, pattern in ipairs(patterns) do
    local result, count = name:gsub(pattern[1], pattern[2])
    if count > 0 then
      return result
    end
  end

  -- Unknown pattern: append " complete"
  return name .. " complete"
end

--- Start tracking an operation with live elapsed time
--- @param name string The operation name to display (e.g., "Pushing to origin/main")
--- @return NeogitOperationHandle|nil
function M.start_operation(name)
  if not fidget_ok then
    return nil
  end

  local handle = fidget_progress.handle.create {
    title = "Neogit",
    message = name .. "... (0.0s)",
    lsp_client = { name = "neogit" },
  }

  local start_time = vim.uv.now()
  local finished = false

  local timer = vim.uv.new_timer()
  timer:start(100, 100, function()
    vim.schedule(function()
      if finished then
        return
      end
      local elapsed = vim.uv.now() - start_time
      handle:report {
        message = name .. "... (" .. format_time(elapsed) .. ")",
      }
    end)
  end)

  return {
    handle = handle,
    name = name,
    start_time = start_time,
    timer = timer,
    finished = false,
    -- Closure to set the finished flag (captured by timer callback)
    set_finished = function()
      finished = true
    end,
  }
end

--- Mark operation as successfully completed
--- Shows final duration and finishes the handle
--- @param op NeogitOperationHandle|nil
function M.finish_operation(op)
  if not op or op.finished or not op.handle then
    return
  end

  op.finished = true
  op.set_finished()

  op.timer:stop()
  op.timer:close()

  local elapsed = vim.uv.now() - op.start_time
  local past_tense = to_past_tense(op.name)

  op.handle:report {
    message = past_tense .. " (" .. format_time(elapsed) .. ")",
  }
  op.handle:finish()
end

--- Mark operation as failed
--- Shows failure message and finishes the handle
--- @param op NeogitOperationHandle|nil
--- @param message string|nil Optional failure message
function M.fail_operation(op, message)
  if not op or op.finished or not op.handle then
    return
  end

  op.finished = true
  op.set_finished()

  op.timer:stop()
  op.timer:close()

  local elapsed = vim.uv.now() - op.start_time
  local fail_message = message or "Failed"

  op.handle:report {
    message = fail_message .. " (" .. format_time(elapsed) .. ")",
  }
  op.handle:finish()
end

return M
