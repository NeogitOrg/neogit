# Optimize Push/Pull Module Performance

## Context

After implementing module filtering for fast staging operations, users are reporting that `update_unmerged` (from the push module) and `update_unpulled` (from the pull module) take **>1.5 seconds**, especially when:
- Committing changes
- Switching branches  
- Any operation that triggers a full refresh

This is now one of the main remaining performance bottlenecks in Neogit.

## Goals

1. **Reduce push/pull module execution time from >1.5s to <200ms**
2. **Skip push/pull modules when they're unnecessary** (e.g., staging files, simple status changes)
3. **Make upstream/pushRemote checks lazy** (only when user views those sections)
4. **Improve memoization** with smarter cache invalidation

## Non-Goals

- Removing push/pull status entirely (users need to see unpulled/unmerged commits)
- Breaking compatibility with existing configs
- Changing the UI layout or section visibility

## Root Cause Analysis

### What `update_unmerged` and `update_unpulled` Do

**`update_unmerged` (lua/neogit/lib/git/push.lua:34-54):**
```lua
local function update_unmerged(state)
  local status = git.branch.status()  -- Fast: git status --porcelain=2 --branch

  if status.upstream then
    -- SLOW: git log with formatting, parsing, present_commit for each
    state.upstream.unmerged.items =
      util.filter_map(git.log.list({ "@{upstream}.." }, nil, {}, true), git.log.present_commit)
  end

  local pushRemote = git.branch.pushRemote_ref()
  if pushRemote then
    -- SLOW: Another git log call
    state.pushRemote.unmerged.items =
      util.filter_map(git.log.list({ pushRemote .. ".." }, nil, {}, true), git.log.present_commit)
  end
end
```

**`update_unpulled` (lua/neogit/lib/git/pull.lua:13-35):**
```lua
local function update_unpulled(state)
  local status = git.branch.status()

  if status.upstream then
    state.upstream.unpulled.items =
      util.filter_map(git.log.list({ "..@{upstream}" }, nil, {}, true), git.log.present_commit)
  end

  local pushRemote = git.branch.pushRemote_ref()
  if pushRemote then
    state.pushRemote.unpulled.items = util.filter_map(
      git.log.list({ string.format("..%s", pushRemote) }, nil, {}, true),
      git.log.present_commit
    )
  end
end
```

### Performance Breakdown

Each module makes **up to 2 git log calls**:
1. `git log @{upstream}..` (or `..@{upstream}`)
2. `git log <pushRemote>..` (or `..<pushRemote>`)

**Each `git.log.list()` call:**

1. **Runs git log with complex formatting** (lua/neogit/lib/git/log.lua:363-400):
   - Format string: `%H`, `%h`, `%T`, `%t`, `%P`, `%p`, `%D`, `%e`, `%s`, `%f`, `%b`, `%N`, `%aN`, `%aE`, `%aD`, `%cN`, `%cE`, `%cD`, `%cr`, `%cd`, `%ct`
   - Args: `--no-patch`, `--max-count=256`, `--topo-order` (if graph)
   - Cost: **200-500ms** in typical repos, **500-1500ms** in large repos with long history

2. **Parses structured output with record.decode()**
   - Cost: **10-50ms** depending on commit count

3. **Calls `present_commit()` for each commit** (lua/neogit/lib/git/log.lua:464-482):
   - Formats commit message
   - Calls `M.branch_info(commit.ref_name, git.remote.list())` - **memoized**
   - If `shortstat` enabled (margin setting): runs `git show --shortstat <oid>` for **EACH commit** (**VERY SLOW**)
   - Cost: **5-10ms per commit normally**, **50-200ms per commit if shortstat enabled**

4. **Total for one git.log.list() call:**
   - Without shortstat: **200-550ms**
   - With shortstat (10 commits): **500-2000ms+**

Since both `update_unmerged` and `update_unpulled` run, and each may make 2 calls:
- **Typical case**: 4 × 300ms = **1200ms**
- **With shortstat**: 4 × 800ms = **3200ms+**
- **If pushRemote == upstream**: Still runs both queries (wasted work)

### Why Memoization Doesn't Help Enough

`git.log.list()` is memoized (lua/neogit/lib/util.lua memoize function):
- **Cache key**: `{cwd, options, graph, files, hidden, graph_color}`
- **Cache timeout**: 5000ms (default)
- **Invalidation**: After 5 seconds, cache is cleared

**Problems:**
1. **After a commit/checkout, refs change** - different rev range, cache miss
2. **Timeout is too short** - User commits, waits 5s, stages a file → cache expired, runs again
3. **No ref-based invalidation** - Cache doesn't know if `@{upstream}` points to same commit
4. **Memoization is per-function** - `update_unmerged` and `update_unpulled` both call with same args but separate cache

### When These Modules Run

Currently, push and pull modules run on **almost every refresh**:

| Action | Current Modules | Should Run? |
|--------|----------------|-------------|
| Stage file | status only ✓ | No |
| Unstage file | status only ✓ | No |
| Discard file | status only ✓ | No |
| File watcher | status only ✓ | No |
| **Commit** | **ALL 12** | branch, log, status (not push/pull!) |
| **Branch checkout** | **ALL 12** | ALL (upstream may change) |
| Push | ALL 12 | status, push, branch |
| Pull | ALL 12 | status, pull, push, branch, log |
| Open Neogit | ALL 12 | ALL |
| Manual refresh | ALL 12 | ALL |

The good news: **Module filtering is already implemented** (Phase 0 of previous plan). We just need to apply it to commits and checkouts!

## Approach

We'll implement optimizations in order of impact (highest ROI first).

### Phase 1: Skip Push/Pull on Commits (Immediate 1.5s Win)

**Problem:** Commits trigger full refresh with all 12 modules, including push/pull.

**Why it's wrong:** A commit only changes:
- `HEAD` pointer (branch module handles this)
- Commit log (log module handles this)
- Working tree status (status module handles this)

A commit does **not** change:
- What commits exist on `@{upstream}` (pull module)
- What commits are unmerged to upstream (push module)
- What refs the remote has (these don't change without fetch/pull/push)

**Solution:** Filter commit refreshes to only run `status`, `branch`, and `log` modules.

**Impact:** Saves **1.5s** on every commit.

**Files to modify:**
- Commit actions don't directly trigger refresh - the `NeogitCommitComplete` event does
- Need to check watcher or status buffer event handlers

### Phase 2: Optimize update_unmerged/update_unpulled (0.5-1s Win)

**Problem:** Even when these modules must run, they're doing unnecessary work.

**Optimizations:**

1. **Skip pushRemote if it's the same as upstream**
   - Many repos have `pushRemote == upstream`
   - No need to run two identical queries
   
2. **Use `git rev-list --count` first** to check if there are any commits
   - If count is 0, skip the expensive `git log` with formatting
   - `git rev-list --count @{upstream}..` is **~10ms** vs **300ms** for full log
   
3. **Skip present_commit if section is folded**
   - Only need commit count/existence for folded sections
   - Full formatting only needed when user opens the section
   - This requires architectural change (lazy loading per section)

### Phase 3: Smarter Memoization (0.3-0.5s Win on Repeated Actions)

**Problem:** Cache invalidates too quickly and doesn't understand git semantics.

**Solution:** Ref-aware caching with longer timeout.

1. **Include ref OIDs in cache key**, not just ref names
   - Key: `{cwd, "git-log", "@{upstream}..", <upstream_oid>}`
   - If `@{upstream}` still points to same OID, use cache
   - Only invalidate when ref moves

2. **Increase cache timeout to 60 seconds**
   - User typically does multiple operations in quick succession
   - Refs don't change unless fetch/pull/push/commit happens
   
3. **Shared cache for push/pull**
   - `update_unmerged` queries `@{upstream}..`
   - `update_unpulled` queries `..@{upstream}`
   - These are related - if one changes, both need refresh
   - Share invalidation signal

### Phase 4: Lazy Section Loading (Future Enhancement)

Make unpulled/unmerged sections fully lazy:
- On initial render, just show "Unpulled from origin/main (fetch to update)"
- When user opens section or explicitly refreshes push/pull (new action?), load commits
- Cache results until next fetch/pull/push

This is a larger architectural change and should be a separate plan.

## Implementation Plan

### Task 1: Filter Commit Refreshes

**Goal:** Only run `status`, `branch`, `log` on commit completion.

**Investigation needed:**
- Where does `NeogitCommitComplete` event trigger refresh?
- Does watcher handle it, or status buffer autocmd?
- What about rebase/cherry-pick/amend?

**Files to check:**
- `lua/neogit/buffers/status/init.lua` - user_autocmds
- `lua/neogit/watcher.lua` - event handling
- `lua/neogit/autocmds.lua` - global autocmds

**Change pattern:**
```lua
-- BEFORE
git.repo:dispatch_refresh { source = "commit" }

-- AFTER  
git.repo:dispatch_refresh { 
  source = "commit",
  modules = { "status", "branch", "log" }
}
```

**Testing:**
- Commit a change
- Verify status updates
- Verify "Recent commits" section updates
- Verify "Unmerged to origin/main" section does NOT update (or shows stale)
- Run manual refresh (`<C-r>`) to update push/pull
- Alternative: Add "refresh push/pull status" action

**Deliverable:** Commits take <500ms instead of 2s.

---

### Task 2: Skip Duplicate pushRemote Queries

**Goal:** If `pushRemote == upstream`, don't run the same query twice.

**File:** `lua/neogit/lib/git/push.lua` and `lua/neogit/lib/git/pull.lua`

**Change:**
```lua
-- In update_unmerged:
local function update_unmerged(state)
  local status = git.branch.status()

  state.upstream.unmerged.items = {}
  state.pushRemote.unmerged.items = {}

  if status.detached then
    return
  end

  if status.upstream then
    state.upstream.unmerged.items =
      util.filter_map(git.log.list({ "@{upstream}.." }, nil, {}, true), git.log.present_commit)
  end

  local pushRemote = require("neogit.lib.git").branch.pushRemote_ref()
  -- NEW: Skip if pushRemote is same as upstream
  if pushRemote and pushRemote ~= status.upstream then
    state.pushRemote.unmerged.items =
      util.filter_map(git.log.list({ pushRemote .. ".." }, nil, {}, true), git.log.present_commit)
  elseif pushRemote == status.upstream then
    -- Copy upstream results to pushRemote
    state.pushRemote.unmerged.items = state.upstream.unmerged.items
  end
end
```

Apply same pattern to `update_unpulled`.

**Testing:**
- Repo where `pushRemote == upstream` (typical case)
- Verify both sections show same commits
- Time improvement: should see ~50% reduction

**Deliverable:** Push/pull modules run 25-50% faster in typical single-remote repos.

---

### Task 3: Fast-Path for Empty Ranges

**Goal:** Use `git rev-list --count` to quickly check if there are commits before doing expensive log formatting.

**File:** `lua/neogit/lib/git/push.lua` and `lua/neogit/lib/git/pull.lua`

**New helper function:**
```lua
local function has_commits_in_range(range)
  local result = git.cli["rev-list"].count.args(range).call({ hidden = true, ignore_error = true })
  if result:success() then
    local count = tonumber(result.stdout[1])
    return count and count > 0
  end
  return false
end
```

**Change update_unmerged:**
```lua
if status.upstream then
  -- Fast check: are there any unmerged commits?
  if has_commits_in_range("@{upstream}..") then
    state.upstream.unmerged.items =
      util.filter_map(git.log.list({ "@{upstream}.." }, nil, {}, true), git.log.present_commit)
  end
  -- If empty, items stays as empty table (already set above)
end
```

**Testing:**
- Repo where local is up-to-date with upstream (common case after pull)
- Should skip expensive git log call
- Verify section shows as empty

**Impact:** 
- When up-to-date: **~10ms** instead of **300ms** (30x faster!)
- When behind: **~10ms + 300ms = 310ms** (small overhead)

**Deliverable:** Push/pull modules nearly instant when up-to-date with remote.

---

### Task 4: Ref-Aware Memoization

**Goal:** Cache git log results until the underlying refs change, not just for 5 seconds.

**File:** Create new module `lua/neogit/lib/git/log_cache.lua`

**Approach:**

1. **Track ref OIDs** when caching log results:
```lua
local M = {}
local cache = {}

---@param ref_range string e.g., "@{upstream}.." or "..origin/main"
---@return CommitLogEntry[]|nil
function M.get(ref_range)
  -- Resolve refs to OIDs
  local from_ref, to_ref = parse_range(ref_range)
  local from_oid = from_ref and resolve_oid(from_ref)
  local to_oid = resolve_oid(to_ref or "HEAD")
  
  local key = string.format("%s..%s", from_oid or "", to_oid)
  return cache[key]
end

function M.set(ref_range, commits)
  local from_ref, to_ref = parse_range(ref_range)
  local from_oid = from_ref and resolve_oid(from_ref)
  local to_oid = resolve_oid(to_ref or "HEAD")
  
  local key = string.format("%s..%s", from_oid or "", to_oid)
  cache[key] = commits
end

function M.clear()
  cache = {}
end
```

2. **Wrap git.log.list for upstream/pushRemote queries:**
```lua
-- In push.lua / pull.lua
local function log_list_cached(range)
  local cached = require("neogit.lib.git.log_cache").get(range)
  if cached then
    return cached
  end
  
  local result = git.log.list({ range }, nil, {}, true)
  require("neogit.lib.git.log_cache").set(range, result)
  return result
end
```

3. **Invalidate on ref changes:**
```lua
-- In repository.lua, after any operation that changes refs:
-- commit, fetch, pull, push, checkout, reset, rebase, merge
require("neogit.lib.git.log_cache").clear()
```

**Testing:**
- Make a commit
- Check push/pull status (cache miss, slow)
- Stage a file (triggers status-only refresh)
- Check push/pull status again (should be instant - cache hit!)

**Deliverable:** Push/pull modules instant on repeated refreshes within a session.

---

### Task 5: Add "Refresh Push/Pull" Action (Optional)

Since we're skipping push/pull on commits, users may want to manually refresh.

**File:** `lua/neogit/buffers/status/init.lua`

**New action:**
```lua
n_refresh_push_pull = function()
  self:dispatch_refresh({ 
    modules = { "push", "pull" } 
  }, "manual_push_pull_refresh")
end
```

**Mapping:** Add to status mappings, e.g., `gP` or `<leader>gf`

**UI indicator:** If push/pull sections are stale, show "(refresh to update)" hint

**Deliverable:** Users can manually update push/pull status without full refresh.

---

## Testing Strategy

### Performance Benchmarks

Use fidget integration or manual timing:

1. **Baseline (before optimization):**
   - Time from commit completion to status buffer update
   - Time for push/pull modules in fidget

2. **After Task 1 (filter commits):**
   - Commit time should drop by ~1.5s
   - Push/pull sections may show stale data

3. **After Task 2 (skip duplicate pushRemote):**
   - Full refresh should be 25-50% faster
   - Verify sections still show correct data

4. **After Task 3 (fast-path empty ranges):**
   - When up-to-date: push/pull should be <50ms
   - When behind: should be similar to baseline

5. **After Task 4 (ref-aware cache):**
   - Repeated operations should be instant
   - Cache should invalidate after commit/fetch

### Functional Testing

| Scenario | Expected Behavior |
|----------|-------------------|
| Commit with local ahead | Unmerged count increases, unpulled unchanged |
| Fetch with remote ahead | Unpulled count increases, unmerged unchanged |
| Push | Unmerged goes to zero |
| Pull | Unpulled goes to zero |
| Checkout branch | Both sections update correctly |
| Stage file after commit | Push/pull unchanged (stale ok) |
| Manual refresh | Push/pull updates |

### Edge Cases

- Detached HEAD (no upstream)
- No remote configured
- pushRemote different from upstream
- Multiple remotes
- Diverged branches (both ahead and behind)

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Stale push/pull sections after commit | Users may not notice unpushed commits | Add "refresh push/pull" action, or auto-refresh after commit (opt-in) |
| Cache invalidation bugs | Wrong commit counts shown | Conservative: clear cache on any ref change |
| Skipping pushRemote breaks some workflows | Users with different push/pull remotes | Only skip if refs are identical, add config option |
| Fast-path has overhead when not up-to-date | Adds 10ms to every check | Negligible compared to 300ms saved in up-to-date case |

---

## Rollout Plan

### Phase 1: Low-Risk Wins (Tasks 2-3)
- Skip duplicate pushRemote queries
- Fast-path for empty ranges
- These are pure optimizations, no behavior change

### Phase 2: Module Filtering (Task 1)
- Filter commit refreshes to skip push/pull
- This changes behavior (stale sections) but massive perf win
- Add config option: `config.values.refresh_push_pull_on_commit` (default false)

### Phase 3: Advanced Caching (Task 4)
- Ref-aware cache for log results
- Complex invalidation logic, test thoroughly

### Phase 4: User Control (Task 5)
- Add manual refresh action
- Improves UX for Phase 2

---

## Config Options

```lua
require('neogit').setup {
  -- When true, commit will refresh push/pull status (slower but always up-to-date)
  -- When false, commit only refreshes status/branch/log (faster, but push/pull may be stale)
  refresh_push_pull_on_commit = false,
  
  -- When true, always check both upstream and pushRemote even if they're the same ref
  always_check_pushRemote = false,
  
  -- Use fast-path for empty commit ranges (rev-list --count before git log)
  fast_path_empty_ranges = true,
}
```

---

## Success Metrics

| Metric | Before | Target | How to Measure |
|--------|--------|--------|----------------|
| Commit refresh time | 2-3s | <500ms | Fidget timing |
| Push/pull module time (when up-to-date) | 300-500ms | <50ms | Fidget per-module |
| Push/pull module time (when behind) | 300-500ms | ~same | Fidget per-module |
| Repeated refresh (cache hit) | 300-500ms | <10ms | Manual timing |

---

## Future Enhancements

1. **Lazy section loading** - Only fetch push/pull data when section is opened
2. **Background refresh** - Update push/pull asynchronously without blocking UI
3. **Smarter fetch** - Auto-fetch on Neogit open if last fetch >5min ago
4. **Commit count only** - Show "5 commits behind" without fetching full log until section opened
5. **Incremental updates** - If only 1 new commit, only fetch that one, not full range

---

## Related Work

- **Phase 0: Module Filtering** (already implemented) - Enables selective refresh
- **Diff Cache** (already implemented) - Pattern for ref-aware caching
- **Fidget Integration** (already implemented) - Makes performance visible to users
- **Lazy Diff Loading** (already implemented) - Pattern for on-demand expensive operations

This plan builds on existing optimizations and extends the pattern to push/pull modules.
