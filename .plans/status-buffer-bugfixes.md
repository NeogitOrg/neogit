# Status Buffer Bug Fixes - True Lazy Diff Loading

## Goal

Fix three related bugs by implementing true lazy diff loading:
1. **Cursor instability** during buffer/fold loading
2. **Missing refresh** when Neogit tab is not focused  
3. **Slow refresh** performance

The core architectural change: **Only load/parse diff content when the user explicitly opens a fold.** Use porcelain data for everything else.

## Status

Ready for implementation

---

## Root Cause Analysis

### The Problem

After a commit (or any refresh), the status buffer:
1. Re-renders with new state from `git status --porcelain=2`
2. Tries to restore previously-open folds via `_update_on_open`
3. Each open fold triggers `load_diff` callback (async)
4. Each `load_diff` appends content and calls `ui:update()`
5. **Multiple cascading updates cause visual "shifting"**

The TODO at line 640-641 of `lib/ui/init.lua` acknowledges this:
```lua
-- TODO: If a hunk is closed, it will be re-opened on update because the on_open callback runs async :\
```

### Current Flow (Problematic)

```
Commit completes
    ↓
Watcher:dispatch_refresh()
    ↓
git.repo:dispatch_refresh() → runs all 12 modules
    ↓
StatusBuffer:redraw() (without cursor/view params!)
    ↓
ui:render() → saves old fold state
    ↓
ui:update()
    ├─ _update_fold_state() → copies folded state to new nodes
    ├─ Renderer renders buffer
    ├─ Sets buffer lines, folds, highlights
    ├─ _update_on_open() → for each previously-open file:
    │      ↓
    │      load_diff() [ASYNC] → accesses item.diff (triggers git diff)
    │          ↓
    │          this:append(DiffHunks)
    │          ui:update() ← ANOTHER FULL UPDATE!
    │              ↓
    │              Buffer shifts, cursor moves
    └─ Restore cursor (too late, more updates coming)
```

### New Architecture (Solution)

```
Commit completes
    ↓
Watcher:dispatch_refresh()
    ↓
git.repo:dispatch_refresh() → runs status module only (fast!)
    ↓
StatusBuffer:redraw()
    ↓
ui:render()
    ↓
ui:update()
    ├─ Renderer renders file list (porcelain data only)
    ├─ All files shown FOLDED with no diff content
    ├─ NO _update_on_open calls
    └─ Restore cursor ONCE, done.

User opens a file fold (explicit action)
    ↓
n_toggle() / n_open_fold()
    ↓
on_open callback (load_diff)
    ↓
git diff runs async
    ↓
Diff appended, single ui:update()
    ↓
Cursor stays on the file (same line)
```

---

## Architectural Changes

### 1. Remove Automatic Fold Restoration for Files

**Current behavior:** `_update_on_open` re-opens files that were open before refresh.

**New behavior:** Files always start folded after refresh. User re-opens what they want.

**Rationale:** 
- Prevents cascading async updates
- Refresh becomes instant (no git diff calls)
- User is in control of what they see
- Matches mental model: "refresh = show current state"

### 2. Keep Hunk Fold State Within Open Files

If a file IS open (user opened it), preserve hunk fold states within that file during the session. But on refresh, the file closes.

**Optional enhancement:** Could track "recently opened" files and show a subtle indicator that they have cached diff data available.

### 3. Porcelain-Only Initial Render

The initial render uses ONLY data from `git status --porcelain=2`:
- File name
- Mode (M, A, D, R, ?, UU, etc.)
- Original name (for renames)
- File mode changes
- Submodule status

**No diff content** until user explicitly opens the fold.

### 4. True Async Diff Loading

When user opens a fold:
1. Show loading indicator (optional, could just expand immediately with placeholder)
2. Run `git diff` in background
3. Parse diff output
4. Append hunks to component
5. Single `ui:update()` to show content

The cursor should stay on the file row since content is added BELOW.

---

## Implementation Tasks

### Phase 0: Fast Refresh for Actions (Biggest Impact)

The `partial` parameter currently only controls which diffs to invalidate. It doesn't control which modules run. **All 12 modules run on every refresh**, even for simple actions like staging a file.

- [ ] **Add `modules` option to `dispatch_refresh`**
  - File: `lua/neogit/lib/git/repository.lua`
  - Allow specifying which modules to run: `{ modules = { "status" } }`
  
- [ ] **Create fast refresh for stage/unstage actions**
  - File: `lua/neogit/buffers/status/actions.lua`
  - For stage/unstage, only run `status` module:
    ```lua
    self:dispatch_refresh({ 
      update_diffs = { "*:" .. filename },
      modules = { "status" }  -- Only refresh status, not pull/push/log/etc.
    }, "n_stage")
    ```

- [ ] **Create fast refresh for watcher triggers**
  - File: `lua/neogit/watcher.lua`
  - File changes don't affect pull/push/log status, only run `status` module

This alone should take staging from ~3s to ~100ms.

**Module requirements by trigger:**

| Trigger | Modules Needed | Why |
|---------|----------------|-----|
| Stage/unstage file | `status` | Only file lists change |
| Discard changes | `status` | Only file lists change |
| File saved (watcher) | `status` | Only file content changed |
| Commit | `status`, `log`, `branch` | HEAD moved, log changed |
| Push | `status`, `push`, `branch` | Remote tracking changed |
| Pull/fetch | `status`, `pull`, `push`, `log`, `branch` | Everything could change |
| Checkout branch | ALL | Everything could change |
| Open Neogit | ALL | Initial load |
| Manual refresh (`<C-r>`) | ALL | User explicitly wants full refresh |

### Phase 1: Remove Auto-Reopen (Core Fix)

- [ ] **Modify `Ui:update()`** - Remove or disable `_update_on_open` call for file items
  - File: `lua/neogit/lib/ui/init.lua` lines 728-731
  - Option A: Remove the call entirely
  - Option B: Filter to only run for non-file folds (sections, etc.)
  
- [ ] **Modify `Ui:render()`** - Don't save file fold state for restoration
  - File: `lua/neogit/lib/ui/init.lua` lines 672-674
  - Only save section fold state, not file fold state

- [ ] **Simplify `load_diff` callback** - Remove fold state restoration logic
  - File: `lua/neogit/buffers/status/ui.lua` lines 231-237
  - The `prefix` parameter and `_node_fold_state` lookup become unnecessary

### Phase 2: Faster Refresh Path

- [ ] **Add "local-only" refresh mode** that skips expensive modules
  - File: `lua/neogit/lib/git/repository.lua`
  - For file-change triggered refreshes, only run `status` module
  - Skip: `pull`, `push`, `log`, `stash` (can be refreshed on-demand)

- [ ] **Increase watcher debounce** from 200ms to 500ms
  - File: `lua/neogit/watcher.lua` line 115
  
- [ ] **Add `TabEnter` autocmd** to StatusBuffer
  - File: `lua/neogit/buffers/status/init.lua` line 265
  - Trigger deferred refresh when switching back to Neogit tab

### Phase 3: Cursor Stability (Should Be Mostly Fixed by Phase 1)

- [ ] **Pass cursor/view to `redraw()`** from watcher callback
  - File: `lua/neogit/watcher.lua` lines 150-159
  - Capture cursor state before refresh, restore after

- [ ] **Ensure single update path** - no cascading `ui:update()` calls
  - Verify that after Phase 1, only one `ui:update()` happens per refresh

### Phase 4: Diff Cache Persistence

Files should retain their loaded diff data across close/reopen within the same Neovim session. This makes reopening Neogit feel instant and reduces "UI shift" when you already explored certain files.

- [ ] **Store diff cache at repository level, not buffer level**
  - File: `lua/neogit/lib/git/repository.lua` (extend existing state) or new module
  - Cache structure:
    ```lua
    diff_cache = {
      ["unstaged:myfile.ts"] = {
        diff = <Diff object>,
        worktree_hash = "abc123",  -- Hash of file content when diff was captured
        index_hash = "def456",     -- Hash of index entry
      }
    }
    ```
  - Key: `section:filename`
  - Invalidation: When status refresh detects file's hashes changed

- [ ] **Check cache in `git.diff.build()`**
  - File: `lua/neogit/lib/git/diff.lua`
  - Before setting up lazy metatable, check if valid cache exists
  - If cached and hashes match, use cached diff directly:
    ```lua
    function M.build(section, item)
      local cache_key = section .. ":" .. item.name
      local cached = diff_cache[cache_key]
      if cached and cached.index_hash == item.index_hash then
        item.diff = cached.diff
        return  -- Skip metatable setup
      end
      -- Otherwise, set up lazy loading as before
      build_metatable(item, raw_output_fn(...))
    end
    ```

- [ ] **Update cache when diff is loaded**
  - When lazy metatable fires and loads diff, store it in cache
  - Include current hashes for invalidation check

- [ ] **Mark files with cached diffs visually** (optional)
  - Different highlight or icon for files with instant-open diffs
  - Helps user know what they can explore without waiting

### Phase 5: Semantic Cursor Restoration

**Good news:** `CursorLocation` already captures semantic position (lib/ui/init.lua lines 404-472):
```lua
---@class CursorLocation
---@field section {index: number, name: string}|nil  -- e.g., {name = "unstaged", index = 2}
---@field file {index: number, name: string}|nil     -- e.g., {name = "myfile.ts", index = 1}
---@field hunk {index: number, name: string, index_from: number}|nil  -- hunk hash for identity
---@field section_offset number|nil  -- offset within section (for non-file sections)
---@field hunk_offset number|nil     -- offset within hunk
```

And `Ui:resolve_cursor_location()` already resolves by name with fallback to index.

**The problem:** Cursor is restored BEFORE `on_open` callbacks complete, so if file.diff.hunks is empty, it falls back to file.first.

**With our Phase 1 fix** (files stay folded on refresh), this becomes a non-issue - there are no `on_open` callbacks during refresh. Cursor restoration happens once, immediately, correctly.

Remaining improvements:

- [ ] **Follow file across sections** when staging/unstaging
  - Current: Cursor on `unstaged/myfile.ts`, stage it, cursor goes to... section header?
  - Better: Cursor follows file to `staged/myfile.ts`
  - Implementation: In `resolve_cursor_location`, if file not found in section, search other sections:
    ```lua
    -- If file not in expected section, check if it moved
    if not file and cursor.file then
      for _, other_section in ipairs(self.item_index) do
        file = Collection.new(other_section.items):find(function(f)
          return f.name == cursor.file.name
        end)
        if file then
          section = other_section
          break
        end
      end
    end
    ```

- [ ] **Preserve cursor within diff when file stays open**
  - If user has file expanded, is looking at hunk 3, and triggers refresh
  - After refresh (file now folded), cache the cursor location
  - When user re-opens the file, restore cursor to hunk 3

- [ ] **Handle disappeared files gracefully**
  - File committed/reverted and no longer in any section
  - Move to: next file in original section → section header → first section

### Phase 6: Fidget.nvim Integration

Add optional fidget.nvim integration to show refresh progress like LSP operations.

- [ ] **Create fidget integration module** `lua/neogit/integrations/fidget.lua`
  - Check if fidget.nvim is installed
  - Create progress handle on refresh start
  - Update progress as modules complete  
  - Finish when refresh completes

- [ ] **Hook into repository refresh** in `lua/neogit/lib/git/repository.lua`
  - Call fidget integration at refresh start/progress/end
  - Track which modules are running/completed
  - Show percentage based on completed modules

**Fidget API usage:**
```lua
local handle = require("fidget.progress").handle.create({
  title = "Refreshing",
  message = "status...",
  lsp_client = { name = "neogit" },
  percentage = 0,
})

handle:report({ message = "branch...", percentage = 25 })
handle:finish()
```

### Phase 7: Polish

- [ ] **Optional: Loading indicator** when opening fold
  - Show "Loading..." or spinner while diff is fetched
  - Replace with actual content when ready

---

## Files to Modify

| File | Changes | Risk |
|------|---------|------|
| `lua/neogit/lib/ui/init.lua` | Remove/modify `_update_on_open` behavior | Medium |
| `lua/neogit/buffers/status/ui.lua` | Simplify `load_diff` callback | Low |
| `lua/neogit/buffers/status/init.lua` | Add `TabEnter` autocmd | Low |
| `lua/neogit/watcher.lua` | Increase debounce, pass cursor to redraw | Low |
| `lua/neogit/lib/git/repository.lua` | Add local-only refresh mode | Medium |

---

## Detailed Code Changes

### 0. Add Module Filtering to Refresh

**File:** `lua/neogit/lib/git/repository.lua`

```lua
-- BEFORE (line 251-261):
function Repo:tasks(filter, state)
  local tasks = {}
  for name, fn in pairs(self.lib) do
    table.insert(tasks, function()
      local start = vim.uv.now()
      fn(state, filter)
      logger.debug(("[REPO]: Refreshed %s in %d ms"):format(name, vim.uv.now() - start))
    end)
  end
  return tasks
end

-- AFTER:
function Repo:tasks(filter, state, only_modules)
  local tasks = {}
  for name, fn in pairs(self.lib) do
    -- Skip modules not in the filter list (if provided)
    if only_modules and not vim.tbl_contains(only_modules, name) then
      -- Preserve existing state for skipped modules
      -- (state is already a deepcopy, so this is a no-op if the key exists)
    else
      table.insert(tasks, function()
        local start = vim.uv.now()
        fn(state, filter)
        logger.debug(("[REPO]: Refreshed %s in %d ms"):format(name, vim.uv.now() - start))
      end)
    end
  end
  return tasks
end
```

```lua
-- BEFORE (line 328-340):
local on_complete = a.void(function()
  self.running[start] = false
  if self.interrupt[start] then
    logger.debug("[REPO]: (" .. start .. ") Interrupting on_complete callback")
    return
  end

  logger.debug("[REPO]: (" .. start .. ") Refreshes complete in " .. timestamp() - start .. " ms")
  self:set_state(start)
  self:run_callbacks(start)
end)

a.util.run_all(self:tasks(filter, self:current_state(start)), on_complete)

-- AFTER (use a.join for cleaner parallel execution):
local tasks = self:tasks(filter, self:current_state(start), opts.modules)

-- IMPORTANT: a.join blocks forever on empty list, so check first
if #tasks > 0 then
  a.join(tasks)
end

self.running[start] = false
if self.interrupt[start] then
  logger.debug("[REPO]: (" .. start .. ") Interrupting after tasks")
  return
end

logger.debug("[REPO]: (" .. start .. ") Refreshes complete in " .. timestamp() - start .. " ms")
self:set_state(start)
self:run_callbacks(start)
```

Note: The entire `Repo:refresh()` function is already called within an async context via `Repo.dispatch_refresh = a.void(...)`, so `a.join` will work correctly.

**IMPORTANT:** `a.join({})` blocks forever! Always check `#tasks > 0` before calling.

**File:** `lua/neogit/buffers/status/actions.lua`

```lua
-- BEFORE (line 1180-1181):
git.status.stage { stagable.filename }
self:dispatch_refresh({ update_diffs = { "*:" .. stagable.filename } }, "n_stage")

-- AFTER:
git.status.stage { stagable.filename }
self:dispatch_refresh({ 
  update_diffs = { "*:" .. stagable.filename },
  modules = { "status" }  -- Only need to refresh file lists
}, "n_stage")
```

Apply similar change to ALL stage/unstage calls in actions.lua.

**File:** `lua/neogit/watcher.lua`

```lua
-- BEFORE (line 150-159):
function Watcher:dispatch_refresh()
  git.repo:dispatch_refresh {
    source = "watcher",
    callback = function()
      for name, buffer in pairs(self.buffers) do
        buffer:redraw()
      end
    end,
  }
end

-- AFTER:
function Watcher:dispatch_refresh()
  git.repo:dispatch_refresh {
    source = "watcher",
    modules = { "status" },  -- File changes only need status refresh
    callback = function()
      for name, buffer in pairs(self.buffers) do
        buffer:redraw()
      end
    end,
  }
end
```

### 1. Remove `_update_on_open` from refresh flow

**File:** `lua/neogit/lib/ui/init.lua`

```lua
-- BEFORE (lines 728-731):
-- Run on_open callbacks for hunks once buffer is rendered
if self._node_fold_state then
  self:_update_on_open(self.layout, self._node_fold_state)
  self._node_fold_state = nil
end

-- AFTER:
-- Don't auto-reopen folds - let user explicitly open what they want
self._node_fold_state = nil
```

### 2. Keep section fold state, not file fold state

**File:** `lua/neogit/lib/ui/init.lua`

Modify `folded_node_state` to only capture section-level folds, not file-level:

```lua
-- In folded_node_state function, add check:
if node.options.section then  -- Only capture section folds
  state[prefix] = { folded = node.options.folded }
end
-- Skip file items (they have options.filename)
```

### 3. Simplify `load_diff`

**File:** `lua/neogit/buffers/status/ui.lua`

```lua
-- BEFORE (lines 214-245):
local load_diff = function(item)
  return a.void(function(this, ui, prefix)
    this.options.on_open = nil
    this.options.folded = false

    local row, _ = this:row_range_abs()
    row = row + 1

    local diff = item.diff
    for _, hunk in ipairs(diff.hunks) do
      hunk.first = row
      hunk.last = row + hunk.length
      row = hunk.last + 1

      -- Set fold state when called from ui:update()
      if prefix then
        local key = ("%s--%s"):format(prefix, hunk.hash)
        if ui._node_fold_state and ui._node_fold_state[key] then
          hunk._folded = ui._node_fold_state[key].folded
        end
      end
    end

    ui.buf:with_locked_viewport(function()
      this:append(DiffHunks(diff))
      ui:update()
    end)
  end)
end

-- AFTER:
local load_diff = function(item)
  return a.void(function(this, ui)
    this.options.on_open = nil
    this.options.folded = false

    local diff = item.diff  -- Triggers lazy load via metatable
    
    local row, _ = this:row_range_abs()
    row = row + 1
    for _, hunk in ipairs(diff.hunks) do
      hunk.first = row
      hunk.last = row + hunk.length
      row = hunk.last + 1
    end

    this:append(DiffHunks(diff))
    ui:update()
  end)
end
```

### 4. Add TabEnter autocmd

**File:** `lua/neogit/buffers/status/init.lua`

```lua
-- In the autocmds table (around line 265):
autocmds = {
  ["User:NeogitReset"] = self:deferred_refresh("reset"),
  ["User:NeogitBranchReset"] = self:deferred_refresh("branch_reset"),
  ["FocusGained"] = self:deferred_refresh("focused", 10),
  ["TabEnter"] = function()
    if self.buffer and self.buffer:is_visible() then
      self:deferred_refresh("tab_enter", 50)()
    end
  end,
}
```

---

## Testing Strategy

### Test 1: Post-Commit Stability
1. Stage some files
2. Open several file folds to view diffs
3. Commit (`cc`, write message, `:wq`)
4. **Expected:** Status buffer instantly shows empty staged section, no shifting
5. **Expected:** Cursor stays stable

### Test 2: Background Tab Refresh
1. Open Neogit in tab 1
2. Switch to tab 2
3. Edit and save a tracked file
4. Switch back to tab 1
5. **Expected:** Status buffer shows the change

### Test 3: Fold Behavior
1. Open Neogit, view unstaged files
2. Open file fold → diff loads
3. Trigger refresh (`:e` or `<C-r>`)
4. **Expected:** File is now folded, no diff visible
5. Open fold again → diff reloads (or uses cache if still valid)

### Test 4: Large Repository Performance
1. Open Neogit in a large repo with many changes
2. Time the initial load
3. Time a refresh after file change
4. **Expected:** Both should be fast (sub-second)

---

## Migration Notes

This is a **behavior change** that users may notice:
- Files no longer auto-expand after refresh
- Previously, if you had files open, they'd re-open (with shifting)
- Now they stay closed until you open them

This matches the user's stated preference and is more predictable. Could add a config option for old behavior if needed, but recommend shipping the new behavior as default.

---

## Decisions Made

1. **Files always fold on refresh** - Prevents cascading updates, user explicitly opens what they want
2. **Remove `_update_on_open` for files** - The core fix for cursor stability
3. **Keep lazy diff loading via metatable** - Current system is fine, just don't auto-trigger it
4. **Add TabEnter autocmd** - Simple fix for tab-switching refresh issue
5. **Local-only refresh mode** - Skip expensive modules for file-change triggers
