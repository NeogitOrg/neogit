# Fidget Operation Progress Integration

## Goal

Transition long-running git operations to display progress via fidget.nvim (when enabled). Operations should show live elapsed time during execution, and upon completion display the operation name with final duration.

**Why**: Current notifications only show "Pushing to X" at start and "Pushed to X" at end with no indication of progress or duration. Users have no visibility into whether an operation is still running or how long it took.

## Scope

| Priority | Operations | Phase |
|----------|------------|-------|
| **Core** | push, pull, fetch | 3-5 |
| **Network** | fetch submodules, tag prune, remote branch delete | 6 |
| **Interactive** | rebase, merge, cherry-pick, revert | 7 |
| **Long-running** | bisect, worktree creation | 7-8 |

## Status

Ready for implementation

## Current State

### Existing Fidget Integration
- `lua/neogit/integrations/fidget.lua` already exists
- Currently ONLY used for **repository refresh** operations (status, index, etc.)
- Shows per-module completion with duration: `"status (45ms)"`, `"Done (234ms)"`
- Auto-detects fidget.nvim availability via `pcall(require, "fidget.progress")`
- Gracefully degrades when unavailable (returns nil, all calls become no-ops)

### Current Notification Pattern (Push/Pull/Fetch)
```lua
notification.info("Pushing to " .. name)           -- Start
local res = git.push.push_interactive(...)         -- Execute
notification.info("Pushed to " .. name, { dismiss = true })  -- End (replaces start)
```

### Available Timing Information
- `ProcessResult.time` contains execution duration in milliseconds
- Returned after operation completes, not available during execution

## Constraints

1. **Backward compatibility**: Must work when fidget.nvim is not installed
2. **Non-blocking**: Elapsed time updates must not block operation execution
3. **Consistent UX**: All long-running operations should behave similarly
4. **PTY operations**: Push/pull/fetch use `pty = true` for interactive auth - timer must work alongside this

## Decisions Made

### 1. Extend existing fidget module (not create new one)
**Rationale**: The `integrations/fidget.lua` module already handles availability checking and graceful degradation. Adding operation-specific functions keeps related code together.

### 2. Use timer-based elapsed time updates
**Rationale**: Since git operations are blocking (from neogit's perspective), we need a `vim.uv.new_timer()` to update the fidget display while the operation runs. This mirrors the existing spinner implementation.

### 3. Single API for all operations
**Rationale**: Create a unified API (`start_operation`, `finish_operation`, `fail_operation`) rather than operation-specific functions. This keeps the interface simple and extensible.

### 4. Fall back to existing notifications
**Rationale**: When fidget is unavailable, continue using `notification.info/error` so users without fidget see the same behavior as before.

### 5. Update interval: 100ms
**Rationale**: Matches the existing spinner update interval. Provides smooth visual updates without excessive overhead.

## Implementation Tasks

### Phase 1: Extend Fidget Module

**File**: `lua/neogit/integrations/fidget.lua`

Add new types and functions for operation progress:

```lua
--- @class NeogitOperationHandle
--- @field handle table The fidget progress handle
--- @field name string Operation name (e.g., "Pushing to origin/main")
--- @field start_time number Start time from vim.uv.now()
--- @field timer userdata uv_timer for elapsed time updates

--- Start tracking an operation with live elapsed time
--- @param name string The operation name to display
--- @return NeogitOperationHandle|nil
function M.start_operation(name)

--- Mark operation as successfully completed
--- Shows final duration and finishes the handle
--- @param op NeogitOperationHandle|nil
function M.finish_operation(op)

--- Mark operation as failed
--- Shows failure message and finishes the handle
--- @param op NeogitOperationHandle|nil
--- @param message string|nil Optional failure message
function M.fail_operation(op, message)
```

**Implementation details**:
- `start_operation` creates fidget handle, starts timer that updates message every 100ms with `"Pushing... (1.2s)"`
- `finish_operation` stops timer, reports final time `"Pushed (3.4s)"`, calls `handle:finish()`
- `fail_operation` stops timer, reports failure `"Failed (2.1s)"`, calls `handle:finish()`
- All functions check for nil handle (graceful degradation)

### Phase 2: Create Operation Wrapper

**File**: `lua/neogit/lib/operation.lua` (new file)

A thin wrapper that coordinates fidget progress with fallback notifications:

```lua
local fidget = require("neogit.integrations.fidget")
local notification = require("neogit.lib.notification")

local M = {}

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
--- @param op Operation
function M.finish(op)
  if op.use_fidget then
    fidget.finish_operation(op.fidget_handle)
  else
    notification.info(op.name .. " complete", { dismiss = true })
  end
end

--- Mark operation as failed
--- @param op Operation
--- @param message string|nil
function M.fail(op, message)
  if op.use_fidget then
    fidget.fail_operation(op.fidget_handle, message)
  else
    notification.error(message or (op.name .. " failed"), { dismiss = true })
  end
end

return M
```

### Phase 3: Update Push Actions

**File**: `lua/neogit/popups/push/actions.lua`

Modify `push_to()` to use the operation wrapper:

```lua
local operation = require("neogit.lib.operation")

local function push_to(args, remote, branch, opts)
  -- ... existing setup code ...
  
  local name = branch and (remote .. "/" .. branch) or remote
  local op = operation.start("Pushing to " .. name)
  
  local res = git.push.push_interactive(remote, branch, args)
  
  -- Handle permission errors
  if res.code == 128 then
    operation.fail(op, table.concat(res.stdout, "\n"))
    return
  end
  
  -- ... existing force-push handling ...
  
  if res and res:success() then
    a.util.scheduler()
    operation.finish(op)
    event.send("PushComplete")
  else
    operation.fail(op, "Failed to push to " .. name)
  end
end
```

### Phase 4: Update Pull Actions

**File**: `lua/neogit/popups/pull/actions.lua`

Modify `pull_from()`:

```lua
local operation = require("neogit.lib.operation")

local function pull_from(args, remote, branch, opts)
  local name = remote .. "/" .. branch
  local op = operation.start("Pulling from " .. name)
  
  local res = git.pull.pull_interactive(remote, branch, args)
  
  if res and res:success() then
    a.util.scheduler()
    operation.finish(op)
    event.send("PullComplete")
  else
    operation.fail(op, "Failed to pull from " .. name)
    if res.code == 128 then
      notification.info(table.concat(res.stdout, "\n"))
    end
  end
end
```

### Phase 5: Update Fetch Actions

**File**: `lua/neogit/popups/fetch/actions.lua`

Modify `fetch_from()`:

```lua
local operation = require("neogit.lib.operation")

local function fetch_from(name, remote, branch, args)
  local op = operation.start("Fetching from " .. name)
  local res = git.fetch.fetch_interactive(remote, branch, args)
  
  if res and res:success() then
    a.util.scheduler()
    operation.finish(op)
    event.send("FetchComplete", { remote = remote, branch = branch })
  else
    operation.fail(op, "Failed to fetch from " .. name)
  end
end
```

Also update `fetch_submodules()` and `fetch_refspec()` similarly.

### Phase 6: Additional Network Operations

**File**: `lua/neogit/popups/fetch/actions.lua`

Update `fetch_submodules()`:
```lua
function M.fetch_submodules(_)
  local op = operation.start("Fetching submodules")
  git.cli.fetch.recurse_submodules.verbose.jobs(4).call()
  operation.finish(op)
end
```

**File**: `lua/neogit/popups/tag/actions.lua`

Update `prune()` for tag fetching/pruning:
```lua
-- Around the remote tag fetching
local op = operation.start("Fetching remote tags")
local remote_tags = git.tag.list_remote()
-- ... comparison logic ...
if needs_push then
  operation.finish(op)
  local push_op = operation.start("Pruning remote tags")
  git.cli.push...
  operation.finish(push_op)
else
  operation.finish(op)
end
```

**File**: `lua/neogit/popups/branch/actions.lua`

Update remote branch deletion in `delete_branch()`:
```lua
-- When deleting remote branch (line ~324)
local op = operation.start("Deleting " .. remote .. "/" .. branch_name)
git.cli.push.remote(remote).delete.to(branch_name).call()
operation.finish(op)
```

### Phase 7: Long-Running Local Operations

These operations use `pty = true` or `long = true` and can take significant time.

**File**: `lua/neogit/lib/git/rebase.lua`

Add operation tracking to rebase functions. The actions file (`popups/rebase/actions.lua`) will need updates:
```lua
-- For interactive rebase
local op = operation.start("Rebasing onto " .. target)
local result = git.rebase.onto(target, args)
if result then
  operation.finish(op)
else
  operation.fail(op)
end
```

**File**: `lua/neogit/lib/git/merge.lua`

Update merge to track progress:
```lua
local op = operation.start("Merging " .. branch)
local result = git.merge.merge(branch, args)
if result.code == 0 then
  operation.finish(op)
else
  operation.fail(op, "Merge conflicts")
end
```

**File**: `lua/neogit/popups/bisect/actions.lua`

Update bisect operations (especially `bisect_run` which can be very long):
```lua
function M.bisect_run(popup)
  local op = operation.start("Bisecting with script")
  local result = git.bisect.run(script)
  operation.finish(op)
end
```

**File**: `lua/neogit/lib/git/cherry_pick.lua`

Update cherry pick for multi-commit operations:
```lua
local op = operation.start("Cherry picking " .. #commits .. " commits")
-- ... pick logic ...
operation.finish(op)
```

**File**: `lua/neogit/lib/git/revert.lua`

Update revert operations:
```lua
local op = operation.start("Reverting " .. #commits .. " commits")
-- ... revert logic ...
operation.finish(op)
```

### Phase 8: Medium Priority Operations

**File**: `lua/neogit/popups/worktree/actions.lua`

Update worktree creation:
```lua
function M.checkout_worktree(popup)
  local op = operation.start("Creating worktree")
  -- ... existing logic ...
  operation.finish(op)
end
```

## Files Modified

| File | Change |
|------|--------|
| `lua/neogit/integrations/fidget.lua` | Add `start_operation`, `finish_operation`, `fail_operation` functions |
| `lua/neogit/lib/operation.lua` | **New file** - operation wrapper with fidget/notification fallback |
| `lua/neogit/popups/push/actions.lua` | Use operation wrapper in `push_to()` |
| `lua/neogit/popups/pull/actions.lua` | Use operation wrapper in `pull_from()` |
| `lua/neogit/popups/fetch/actions.lua` | Use operation wrapper in `fetch_from()`, `fetch_submodules()` |
| `lua/neogit/popups/tag/actions.lua` | Use operation wrapper in `prune()` |
| `lua/neogit/popups/branch/actions.lua` | Use operation wrapper in `delete_branch()` (remote) |
| `lua/neogit/popups/rebase/actions.lua` | Use operation wrapper for rebase operations |
| `lua/neogit/lib/git/merge.lua` | Use operation wrapper in `merge()` |
| `lua/neogit/popups/bisect/actions.lua` | Use operation wrapper in bisect operations |
| `lua/neogit/lib/git/cherry_pick.lua` | Use operation wrapper in `pick()` |
| `lua/neogit/lib/git/revert.lua` | Use operation wrapper in `commits()` |
| `lua/neogit/popups/worktree/actions.lua` | Use operation wrapper in worktree creation |

## Operation Categories

| Category | Operations | Characteristics |
|----------|------------|-----------------|
| **Network** | push, pull, fetch, fetch submodules, tag prune, remote branch delete | Depend on network speed, may prompt for auth |
| **Interactive** | rebase, merge, cherry-pick, revert | Use PTY, may open editor, conflict resolution |
| **Long-running** | bisect run, large worktree creation | Marked with `long = true`, can take minutes |

## Testing Strategy

### Manual Testing

1. **With fidget.nvim installed**:
   - Push to remote: verify live elapsed time updates, final time shown
   - Pull from remote: same verification
   - Fetch from remote: same verification
   - Failed operations: verify failure message with duration

2. **Without fidget.nvim**:
   - All operations should fall back to existing notification behavior
   - No errors or warnings about missing fidget

3. **Edge cases**:
   - Very fast operations (< 100ms): should still show completion
   - Interrupted operations (Ctrl-C): timer cleanup, no lingering handles
   - Operations with interactive auth prompts: progress should continue updating

4. **Additional operations** (Phase 6-8):
   - Fetch submodules: verify progress during multi-submodule fetch
   - Rebase: verify progress persists through editor interactions
   - Merge with conflicts: verify failure state shows correctly
   - Bisect run: verify long-running script execution shows progress
   - Remote branch delete: verify network operation tracking

### Verification Commands

```vim
" Core operations (Phase 3-5)
:Neogit push
:Neogit pull
:Neogit fetch

" Additional network operations (Phase 6)
" From fetch popup, select 'f' for submodules

" Long-running operations (Phase 7)
" From rebase popup, test interactive rebase
" From bisect popup, test bisect run

" Verify fidget detection
:lua print(require("neogit.integrations.fidget").available())
```

## Display Format

During operation:
```
Pushing to origin/main... (1.2s)
```

On success:
```
Pushed to origin/main (3.4s)
```

On failure:
```
Push failed (2.1s)
```

The elapsed time updates every 100ms. Format uses one decimal place for times under 10s, whole seconds otherwise.

## Open Questions

None - ready for implementation.
