local fidget = require("neogit.integrations.fidget")
local notification = require("neogit.lib.notification")

local M = {}

--- Convert operation name from present progressive to past tense for notification fallback
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

--- @class Operation
--- @field name string
--- @field fidget_handle NeogitOperationHandle|nil
--- @field use_fidget boolean

--- Start an operation with progress tracking
--- @param name string The operation name (e.g., "Pushing to origin/main")
--- @return Operation
function M.start(name)
  local op = {
    name = name,
    use_fidget = fidget.available(),
  }

  if op.use_fidget then
    op.fidget_handle = fidget.start_operation(name)
  else
    notification.info(name .. "...")
  end

  return op
end

--- Mark operation as complete
--- @param op Operation|nil
function M.finish(op)
  if not op then
    return
  end

  if op.use_fidget then
    fidget.finish_operation(op.fidget_handle)
  else
    notification.info(to_past_tense(op.name), { dismiss = true })
  end
end

--- Mark operation as failed
--- @param op Operation|nil
--- @param message string|nil Optional failure message
function M.fail(op, message)
  if not op then
    return
  end

  if op.use_fidget then
    fidget.fail_operation(op.fidget_handle, message)
  else
    notification.error(message or (op.name .. " failed"), { dismiss = true })
  end
end

return M
