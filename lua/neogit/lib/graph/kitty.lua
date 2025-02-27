-- Modified version of graphing algorithm from https://github.com/isakbm/gitgraph.nvim
--
-- MIT License
--
-- Copyright (c) 2024 Isak Buhl-Mortensen
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local M = {}

-- heuristic to check if this row contains a "bi-crossing" of branches
--
-- a bi-crossing is when we have more than one branch "propagating" horizontally
-- on a connector row
--
-- this can only happen when the commit on the row
-- above the connector row is a merge commit
-- but it doesn't always happen
--
-- in addition to needing a merge commit on the row above
-- we need the span (interval) of the "emphasized" connector cells
-- (they correspond to connectors to the parents of the merge commit)
-- we need that span to overlap with at least one connector cell that
-- is destined for the commit on the next row
-- (the commit before the merge commit)
-- in addition, we need there to be more than one connector cell
-- destined to the next commit
--
-- here is an example
--
--
--   j i i          ⓮ │ │   j -> g h
--   g i i h        ?─?─?─╮
--   g i   h        │ ⓚ   │ i
--
--
-- overlap:
--
--   g-----h 1 4
--     i-i   2 3
--
-- NOTE how `i` is the commit that the `i` cells are destined for
--      notice how there is more than on `i` in the connector row
--      and that it lies in the span of g-h
--
-- some more examples
--
-- -------------------------------------
--
--   S T S          │ ⓮ │ T -> R S
--   S R S          ?─?─?
--   S R            ⓚ │   S
--
--
-- overlap:
--
--   S-R    1 2
--   S---S  1 3
--
-- -------------------------------------
--
--
--   c b a b        ⓮ │ │ │ c -> Z a
--   Z b a b        ?─?─?─?
--   Z b a          │ ⓚ │   b
--
-- overlap:
--
--   Z---a    1 3
--     b---b  2 4
--
-- -------------------------------------
--
-- finally a negative example where there is no problem
--
--
--   W V V          ⓮ │ │ W -> S V
--   S V V          ⓸─⓵─╯
--   S V            │ ⓚ   V
--
-- no overlap:
--
--   S-V    1 2
--     V-V  2 3
--
-- the reason why there is no problem (bi-crossing) above
-- follows from the fact that the span from V <- V only
-- touches the span S -> V it does not overlap it, so
-- figuratively we have S -> V <- V which is fine
--
-- TODO:
-- FIXME: need to test if we handle two bi-connectors in succession
--        correctly
--
---@param commit_row I.Row
---@param connector_row I.Row
---@param next_commit I.Commit?
---@return boolean -- whether or not this is a bi crossing
---@return boolean -- whether or not it can be resolved safely by edge lifting
local function get_is_bi_crossing(commit_row, connector_row, next_commit)
  if not next_commit then
    return false, false
  end

  local prev = commit_row.commit
  assert(prev, "expected a prev commit")

  if #prev.parents < 2 then
    return false, false -- bi-crossings only happen when prev is a merge commit
  end

  local row = connector_row

  ---@param k integer
  local function interval_upd(x, k)
    if k < x.start then
      x.start = k
    end
    if k > x.stop then
      x.stop = k
    end
  end

  -- compute the emphasized interval (merge commit parent interval)
  local emi = { start = #row.cells, stop = 1 }
  for k, cell in ipairs(row.cells) do
    if cell.commit and cell.emphasis then
      interval_upd(emi, k)
    end
  end

  -- compute connector interval
  local coi = { start = #row.cells, stop = 1 }
  for k, cell in ipairs(row.cells) do
    if cell.commit and cell.commit.hash == next_commit.hash then
      interval_upd(coi, k)
    end
  end

  -- unsafe if starts of intervals overlap and are equal to direct parent location
  local safe = not (emi.start == coi.start and prev.j == emi.start)

  -- return early when connector interval is trivial
  if coi.start == coi.stop then
    return false, safe
  end

  -- print('emi:', vim.inspect(emi))
  -- print('coi:', vim.inspect(coi))

  -- check overlap
  do
    -- are intervals identical, then that counts as overlap
    if coi.start == emi.start and coi.stop == emi.stop then
      return true, safe
    end
  end
  for _, k in pairs(emi) do
    -- emi endpoints inside coi ?
    if coi.start < k and k < coi.stop then
      return true, safe
    end
  end
  for _, k in pairs(coi) do
    -- coi endpoints inside emi ?
    if emi.start < k and k < emi.stop then
      return true, safe
    end
  end

  return false, safe
end

---@param next I.Commit
---@param prev_commit_row I.Row
---@param prev_connector_row I.Row
---@param commit_row I.Row
---@param connector_row I.Row
local function resolve_bi_crossing(prev_commit_row, prev_connector_row, commit_row, connector_row, next)
  -- if false then
  -- if false then -- get_is_bi_crossing(graph, next_commit, #graph) then
  -- print 'we have a bi crossing'
  -- void all repeated reservations of `next` from
  -- this and the previous row
  local prev_row = commit_row
  local this_row = connector_row
  assert(prev_row and this_row, "expecting two prior rows due to bi-connector")

  --- example of what this does
  ---
  --- input:
  ---
  ---   j i i          │ │ │
  ---   j i i          ⓮ │ │     <- prev
  ---   g i i h        ⓸─⓵─ⓥ─╮   <- bi connector
  ---
  --- output:
  ---
  ---   j i i          │ ⓶─╯
  ---   j i            ⓮ │       <- prev
  ---   g i   h        ⓸─│───╮   <- bi connector
  ---
  ---@param row I.Row
  ---@return integer
  local function void_repeats(row)
    local start_voiding = false
    local ctr = 0
    for k, cell in ipairs(row.cells) do
      if cell.commit and cell.commit.hash == next.hash then
        if not start_voiding then
          start_voiding = true
        elseif not row.cells[k].emphasis then
          -- else

          row.cells[k] = { connector = " " } -- void it
          ctr = ctr + 1
        end
      end
    end
    return ctr
  end

  void_repeats(prev_row)
  void_repeats(this_row)

  -- we must also take care when the prev prev has a repeat where
  -- the repeat is not the direct parent of its child
  --
  --   G                        ⓯
  --   e d c                    ⓸─ⓢ─╮
  --   E D C F                  │ │ │ ⓯
  --   e D C c b a d            ⓶─⓵─│─⓴─ⓢ─ⓢ─? <--- to resolve this
  --   E D C C B A              ⓮ │ │ │ │ │
  --   c D C C b A              ⓸─│─ⓥ─ⓥ─⓷ │
  --   C D     B A              │ ⓮     │ │
  --   C c     b a              ⓶─ⓥ─────⓵─⓷
  --   C       B A              ⓮       │ │
  --   b       B a              ⓸───────ⓥ─⓷
  --   B         A              ⓚ         │
  --   a         A              ⓶─────────╯
  --   A                        ⓚ
  local prev_prev_row = prev_connector_row -- graph[#graph - 2]
  local prev_prev_prev_row = prev_commit_row -- graph[#graph - 3]
  assert(prev_prev_row and prev_prev_prev_row, "assertion failed")
  do
    local start_voiding = false
    local ctr = 0
    ---@type I.Cell?
    local replacer = nil
    for k, cell in ipairs(prev_prev_row.cells) do
      if cell.commit and cell.commit.hash == next.hash then
        if not start_voiding then
          start_voiding = true
          replacer = cell
        elseif k ~= prev_prev_prev_row.commit.j then
          local ppcell = prev_prev_prev_row.cells[k]
          if (not ppcell) or (ppcell and ppcell.connector == " ") then
            prev_prev_row.cells[k] = { connector = " " } -- void it
            replacer.emphasis = true
            ctr = ctr + 1
          end
        end
      end
    end
  end

  -- assert(prev_rep_ctr == this_rep_ctr)

  -- newly introduced tracking cells can be squeezed in
  --
  -- before:
  --
  --   j i i          │ ⓶─╯
  --   j i            ⓮ │
  --   g i   h        ⓸─│───╮
  --
  -- after:
  --
  --   j i i          │ ⓶─╯
  --   j i            ⓮ │
  --   g i h          ⓸─│─╮
  --
  -- can think of this as scooting the cell to the left
  -- when the cell was just introduced
  -- TODO: implement this at some point
  -- for k, cell in ipairs(this_row.cells) do
  --   if cell.commit and not prev_row.cells[k].commit and not this_row.cells[k - 2] then
  --   end
  -- end
end

---@class I.Row
---@field cells I.Cell[]
---@field commit I.Commit? -- there's a single commit for every even row

---@class I.Cell
---@field is_commit boolean? -- when true this cell is a real commit
---@field commit I.Commit? -- a cell is associated with a commit, but the empty column gaps don't have them
---@field symbol string?
---@field connector string? -- a cell is eventually given a connector
---@field emphasis boolean? -- when true indicates that this is a direct parent of cell on previous row

---@class I.Commit
---@field hash string
---@field msg string
---@field branch_names string[]
---@field tags string[]
---@field debug string?
---@field author_date string
---@field author_name string
---@field i integer
---@field j integer
---@field parents string[]
---@field children string[]

---@class I.Highlight
---@field hg string
---@field row integer
---@field start integer
---@field stop integer

local sym = {
  merge_commit = "",
  commit = "",
  merge_commit_end = "",
  commit_end = "",
  GVER = "",
  GHOR = "",
  GCLD = "",
  GCRD = "╭",
  GCLU = "",
  GCRU = "",
  GLRU = "",
  GLRD = "",
  GLUD = "",
  GRUD = "",
  GFORKU = "",
  GFORKD = "",
  GRUDCD = "",
  GRUDCU = "",
  GLUDCD = "",
  GLUDCU = "",
  GLRDCL = "",
  GLRDCR = "",
  GLRUCL = "",
  GLRUCR = "",
}

local BRANCH_COLORS = {
  "Red",
  "Yellow",
  "Blue",
  "Purple",
  "Cyan",
}

local NUM_BRANCH_COLORS = #BRANCH_COLORS

local util = require("neogit.lib.util")

---@param commits CommitLogEntry[]
---@param color boolean?
function M.build(commits, color)
  local GVER = sym.GVER
  local GHOR = sym.GHOR
  local GCLD = sym.GCLD
  local GCRD = sym.GCRD
  local GCLU = sym.GCLU
  local GCRU = sym.GCRU
  local GLRU = sym.GLRU
  local GLRD = sym.GLRD
  local GLUD = sym.GLUD
  local GRUD = sym.GRUD

  local GFORKU = sym.GFORKU
  local GFORKD = sym.GFORKD

  local GRUDCD = sym.GRUDCD
  local GRUDCU = sym.GRUDCU
  local GLUDCD = sym.GLUDCD
  local GLUDCU = sym.GLUDCU

  local GLRDCL = sym.GLRDCL
  local GLRDCR = sym.GLRDCR
  local GLRUCL = sym.GLRUCL
  -- local GLRUCR = sym.GLRUCR

  local GRCM = sym.commit
  local GMCM = sym.merge_commit
  local GRCME = sym.commit_end
  local GMCME = sym.merge_commit_end

  local raw_commits = util.filter_map(commits, function(item)
    if item.oid then
      return {
        msg = item.subject,
        branch_names = {},
        tags = {},
        author_date = item.author_date,
        hash = item.oid,
        parents = vim.split(item.parent, " "),
      }
    end
  end)

  local commits = {} ---@type table<string, I.Commit>
  local sorted_commits = {} ---@type string[]

  for _, rc in ipairs(raw_commits) do
    local commit = {
      msg = rc.msg,
      branch_names = rc.branch_names,
      tags = rc.tags,
      author_date = rc.author_date,
      author_name = rc.author_name,
      hash = rc.hash,
      i = -1,
      j = -1,
      parents = rc.parents,
      children = {},
    }

    sorted_commits[#sorted_commits + 1] = commit.hash
    commits[rc.hash] = commit
  end

  do
    for _, c_hash in ipairs(sorted_commits) do
      local c = commits[c_hash]

      for _, h in ipairs(c.parents) do
        local p = commits[h]
        if p then
          p.children[#p.children + 1] = c.hash
        else
          -- create a virtual parent, it is not added to the list of commit hashes
          commits[h] = {
            hash = h,
            author_name = "virtual",
            msg = "virtual parent",
            author_date = "unknown",
            parents = {},
            children = { c.hash },
            branch_names = {},
            tags = {},
            i = -1,
            j = -1,
          }
        end
      end
    end
  end

  ---@param cells I.Cell[]
  ---@return I.Cell[]
  local function propagate(cells)
    local new_cells = {}
    for _, cell in ipairs(cells) do
      if cell.connector then
        -- new_cells[#new_cells + 1] = { connector = " " }
        new_cells[#new_cells + 1] = { connector = cell.connector }
      elseif cell.commit then
        assert(cell.commit, "assertion failed")
        new_cells[#new_cells + 1] = { commit = cell.commit }
      else
        new_cells[#new_cells + 1] = { connector = " " }
      end
    end
    return new_cells
  end

  ---@param cells I.Cell[]
  ---@param hash string
  ---@param start integer?
  ---@return integer?
  local function find(cells, hash, start)
    local start = start or 1
    for idx = start, #cells, 2 do
      local c = cells[idx]
      if c.commit and c.commit.hash == hash then
        return idx
      end
    end
    return nil
  end

  ---@param cells I.Cell[]
  ---@param start integer?
  ---@return integer
  local function next_vacant_j(cells, start)
    local start = start or 1
    for i = start, #cells, 2 do
      local cell = cells[i]
      if cell.connector == " " then
        return i
      end
    end
    return #cells + 1
  end

  --- returns the generated row and the integer (j) location of the commit
  ---@param c I.Commit
  ---@param prev_row I.Row?
  ---@return I.Row, integer
  local function generate_commit_row(c, prev_row)
    local j = nil ---@type integer?

    local rowc = {} ---@type I.Cell[]

    if prev_row then
      rowc = propagate(prev_row.cells)
      j = find(prev_row.cells, c.hash)
    end

    -- if reserved location use it
    if j then
      c.j = j
      rowc[j] = { commit = c, is_commit = true }

      -- clear any supurfluous reservations
      for k = j + 1, #rowc do
        local v = rowc[k]
        if v.commit and v.commit.hash == c.hash then
          rowc[k] = { connector = " " }
        end
      end
    else
      j = next_vacant_j(rowc)
      c.j = j
      rowc[j] = { commit = c, is_commit = true }
      rowc[j + 1] = { connector = " " }
    end

    return { cells = rowc, commit = c }, j
  end

  ---@param prev_commit_row I.Row
  ---@param prev_connector_row I.Row
  ---@param commit_row I.Row
  ---@param commit_loc integer
  ---@param curr_commit I.Commit
  ---@param next_commit I.Commit?
  ---@return I.Row
  local function generate_connector_row(
    prev_commit_row,
    prev_connector_row,
    commit_row,
    commit_loc,
    curr_commit,
    next_commit
  )
    -- connector row (reservation row)
    --
    -- first we propagate
    local connector_cells = propagate(commit_row.cells)

    -- connector row
    --
    -- now we proceed to add the parents of the commit we just added
    if #curr_commit.parents > 0 then
      ---@param rem_parents string[]
      local function reserve_remainder(rem_parents)
        --
        -- reserve the rest of the parents in slots to the right of us
        --
        -- ... another alternative is to reserve rest of the parents of c if they have not already been reserved
        -- for i = 2, #c.parents do
        for _, h in ipairs(rem_parents) do
          local j = find(commit_row.cells, h, commit_loc)
          if not j then
            local j = next_vacant_j(connector_cells, commit_loc)
            connector_cells[j] = { commit = commits[h], emphasis = true }
            connector_cells[j + 1] = { connector = " " }
          else
            connector_cells[j].emphasis = true
          end
        end
      end

      -- we start by peeking at next commit and seeing if it is one of our parents
      -- we only do this if one of our propagating branches is already destined for this commit
      ---@type I.Cell?
      local tracker = nil
      if next_commit then
        for _, cell in ipairs(connector_cells) do
          if cell.commit and cell.commit.hash == next_commit.hash then
            tracker = cell
            break
          end
        end
      end

      local next_p_idx = nil -- default to picking first parent
      if tracker and next_commit then
        -- this loop updates next_p_idx to the next commit if they are identical
        for k, h in ipairs(curr_commit.parents) do
          if h == next_commit.hash then
            next_p_idx = k
            break
          end
        end
      end

      -- next_p_idx = nil

      -- add parents
      if next_p_idx then
        assert(tracker, "assertion failed")
        -- if next commit is our parent then we do some complex logic
        if #curr_commit.parents == 1 then
          -- simply place parent at our location
          connector_cells[commit_loc].commit = commits[curr_commit.parents[1]]
          connector_cells[commit_loc].emphasis = true
        else
          -- void the cell at our location (will be replaced by our parents in a moment)
          connector_cells[commit_loc] = { connector = " " }

          -- put emphasis on tracker for the special parent
          tracker.emphasis = true

          -- only reserve parents that are different from next commit
          ---@type string[]
          local rem_parents = {}
          for k, h in ipairs(curr_commit.parents) do
            if k ~= next_p_idx then
              rem_parents[#rem_parents + 1] = h
            end
          end

          assert(#rem_parents == #curr_commit.parents - 1, "unexpected amount of rem parents")
          reserve_remainder(rem_parents)

          -- we fill this with the next commit if it is empty, a bit hacky
          if connector_cells[commit_loc].connector == " " then
            connector_cells[commit_loc].commit = tracker.commit
            connector_cells[commit_loc].emphasis = true
            connector_cells[commit_loc].connector = nil
            tracker.emphasis = false
          end
        end
      else
        -- simply add first parent at our location and then reserve the rest
        connector_cells[commit_loc].commit = commits[curr_commit.parents[1]]
        connector_cells[commit_loc].emphasis = true

        local rem_parents = {}
        for k = 2, #curr_commit.parents do
          rem_parents[#rem_parents + 1] = curr_commit.parents[k]
        end

        reserve_remainder(rem_parents)
      end

      local connector_row = { cells = connector_cells } ---@type I.Row

      -- handle bi-connector rows
      local is_bi_crossing, bi_crossing_safely_resolvable =
        get_is_bi_crossing(commit_row, connector_row, next_commit)

      if is_bi_crossing and bi_crossing_safely_resolvable and next_commit then
        resolve_bi_crossing(prev_commit_row, prev_connector_row, commit_row, connector_row, next_commit)
      end

      return connector_row
    else
      -- if we're here then it means that this commit has no common ancestors with other commits
      -- ... a different family ... see test `different family`

      -- we must remove the already propagated connector for the current commit since it has no parents
      for i = 1, #connector_cells, 2 do
        local cell = connector_cells[i]
        if cell.commit and cell.commit.hash == curr_commit.hash then
          connector_cells[i] = { connector = " " }
        end
      end

      local connector_row = { cells = connector_cells }

      return connector_row
    end
  end

  ---@param commits table<string, I.Commit>
  ---@param sorted_commits string[]
  ---@return I.Row[]
  local function straight_j(commits, sorted_commits)
    local graph = {} ---@type I.Row[]

    for i, c_hash in ipairs(sorted_commits) do
      -- get the input parameters
      local curr_commit = commits[c_hash]
      local next_commit = commits[sorted_commits[i + 1]]
      local prev_commit_row = graph[#graph - 1]
      local prev_connector_row = graph[#graph]

      -- generate commit and connector row for the current commit
      local commit_row, commit_loc = generate_commit_row(curr_commit, prev_connector_row)
      local connector_row = nil ---@type I.Row
      if i < #sorted_commits then
        connector_row = generate_connector_row(
          prev_commit_row,
          prev_connector_row,
          commit_row,
          commit_loc,
          curr_commit,
          next_commit
        )
      end

      -- write the result
      graph[#graph + 1] = commit_row
      if connector_row then
        graph[#graph + 1] = connector_row
      end
    end

    return graph
  end

  local graph = straight_j(commits, sorted_commits)

  ---@param graph I.Row[]
  ---@return string[]
  ---@return I.Highlight[]
  local function graph_to_lines(graph)
    ---@type table[]
    local lines = {}

    ---@type I.Highlight[]
    local highlights = {}

    ---@param cell I.Cell
    ---@return string
    local function commit_cell_symb(cell)
      assert(cell.is_commit, "assertion failed")

      if #cell.commit.parents > 1 then
        -- merge commit
        return #cell.commit.children == 0 and GMCME or GMCM
      else
        -- regular commit
        return #cell.commit.children == 0 and GRCME or GRCM
      end
    end

    ---@param row I.Row
    ---@return table
    local function row_to_str(row)
      local row_strs = {}
      for j = 1, #row.cells do
        local cell = row.cells[j]
        if cell.connector then
          cell.symbol = cell.connector -- TODO: connector and symbol should not be duplicating data?
        else
          assert(cell.commit, "assertion failed")
          cell.symbol = commit_cell_symb(cell)
        end
        row_strs[#row_strs + 1] = cell.symbol
      end
      -- return table.concat(row_strs)
      return row_strs
    end

    ---@param row I.Row
    ---@param row_idx integer
    ---@return I.Highlight[]
    local function row_to_highlights(row, row_idx)
      local row_hls = {}
      local offset = 1 -- WAS 0

      for j = 1, #row.cells do
        local cell = row.cells[j]

        local width = cell.symbol and vim.fn.strdisplaywidth(cell.symbol) or 1
        local start = offset
        local stop = start + width

        offset = offset + width

        if cell.commit then
          local hg = (cell.emphasis and "Bold" or "") .. BRANCH_COLORS[(j % NUM_BRANCH_COLORS + 1)]
          row_hls[#row_hls + 1] = {
            hg = hg,
            row = row_idx,
            start = start,
            stop = stop,
          }
        elseif cell.symbol == GHOR then
          -- take color from first right cell that attaches to this connector
          for k = j + 1, #row.cells do
            local rcell = row.cells[k]

            -- TODO: would be nice with a better way than this hacky method of
            --       to figure out where our vertical branch is
            local continuations = {
              GCLD,
              GCLU,
              --
              GFORKD,
              GFORKU,
              --
              GLUDCD,
              GLUDCU,
              --
              GLRDCL,
              GLRUCL,
            }

            if rcell.commit and vim.tbl_contains(continuations, rcell.symbol) then
              local hg = (cell.emphasis and "Bold" or "")
                .. BRANCH_COLORS[(rcell.commit.j % NUM_BRANCH_COLORS + 1)]
              row_hls[#row_hls + 1] = {
                hg = hg,
                row = row_idx,
                start = start,
                stop = stop,
              }

              break
            end
          end
        end
      end

      return row_hls
    end

    local width = 0
    for _, row in ipairs(graph) do
      if #row.cells > width then
        width = #row.cells
      end
    end

    for idx = 1, #graph do
      local proper_row = graph[idx]

      local row_str_arr = {}

      ---@param stuff table|string
      local function add_to_row(stuff)
        row_str_arr[#row_str_arr + 1] = stuff
      end

      local c = proper_row.commit
      if c then
        add_to_row(c.hash) -- Commit row
        add_to_row(row_to_str(proper_row))
      else
        local c = graph[idx - 1].commit
        assert(c, "assertion failed")

        local row = row_to_str(proper_row)
        local valid = false
        for _, char in ipairs(row) do
          if char ~= " " and char ~= GVER then
            valid = true
            break
          end
        end

        if valid then
          add_to_row("") -- Connection Row
        else
          add_to_row("strip") -- Useless Connection Row
        end

        add_to_row(row)
      end

      for _, hl in ipairs(row_to_highlights(proper_row, idx)) do
        highlights[#highlights + 1] = hl
      end

      lines[#lines + 1] = row_str_arr
    end

    return lines, highlights
  end

  -- store stage 1 graph
  --
  ---@param c I.Cell?
  ---@return string?
  local function hash(c)
    return c and c.commit and c.commit.hash
  end

  -- inserts vertical and horizontal pipes
  for i = 2, #graph - 1 do
    local row = graph[i]

    ---@param cells I.Cell[]
    local function count_emph(cells)
      local n = 0
      for _, c in ipairs(cells) do
        if c.commit and c.emphasis then
          n = n + 1
        end
      end
      return n
    end

    local num_emphasized = count_emph(graph[i].cells)

    -- vertical connections
    for j = 1, #row.cells, 2 do
      local this = graph[i].cells[j]
      local below = graph[i + 1].cells[j]

      local tch, bch = hash(this), hash(below)

      if not this.is_commit and not this.connector then
        -- local ch = row.commit and row.commit.hash
        -- local row_commit_is_child = ch and vim.tbl_contains(this.commit.children, ch)
        -- local trivial_continuation = (not row_commit_is_child) and (new_columns < 1 or ach == tch or acc == GVER)
        -- local trivial_continuation = (new_columns < 1 or ach == tch or acc == GVER)
        local ignore_this = (num_emphasized > 1 and (this.emphasis or false))

        if not ignore_this and bch == tch then -- and trivial_continuation then
          local has_repeats = false
          local first_repeat = nil
          for k = 1, #row.cells, 2 do
            local cell_k, cell_j = row.cells[k], row.cells[j]
            local rkc, rjc =
              (not cell_k.connector and cell_k.commit), (not cell_j.connector and cell_j.commit)

            -- local rkc, rjc = row.cells[k].commit, row.cells[j].commit

            if k ~= j and (rkc and rjc) and rkc.hash == rjc.hash then
              has_repeats = true
              first_repeat = k
              break
            end
          end

          if not has_repeats then
            local cell = graph[i].cells[j]
            cell.connector = GVER
          else
            local k = first_repeat
            local this_k = graph[i].cells[k]
            local below_k = graph[i + 1].cells[k]

            local bkc, tkc =
              (not below_k.connector and below_k.commit), (not this_k.connector and this_k.commit)

            -- local bkc, tkc = below_k.commit, this_k.commit
            if (bkc and tkc) and bkc.hash == tkc.hash then
              local cell = graph[i].cells[j]
              cell.connector = GVER
            end
          end
        end
      end
    end

    do
      -- we expect number of rows to be odd always !! since the last
      -- row is a commit row without a connector row following it
      assert(#graph % 2 == 1, "assertion failed")
      local last_row = graph[#graph]
      for j = 1, #last_row.cells, 2 do
        local cell = last_row.cells[j]
        if cell.commit and not cell.is_commit then
          cell.connector = GVER
        end
      end
    end

    -- horizontal connections
    --
    -- a stopped connector is one that has a void cell below it
    --
    local stopped = {}
    for j = 1, #row.cells, 2 do
      local this = graph[i].cells[j]
      local below = graph[i + 1].cells[j]
      if not this.connector and (not below or below.connector == " ") then
        assert(this.commit, "assertion failed")
        stopped[#stopped + 1] = j
      end
    end

    -- now lets get the intervals between the stopped connetors
    -- and other connectors of the same commit hash
    local intervals = {}
    for _, j in ipairs(stopped) do
      local curr = 1
      for k = curr, j do
        local cell_k, cell_j = row.cells[k], row.cells[j]
        local rkc, rjc = (not cell_k.connector and cell_k.commit), (not cell_j.connector and cell_j.commit)
        if (rkc and rjc) and (rkc.hash == rjc.hash) then
          if k < j then
            intervals[#intervals + 1] = { start = k, stop = j }
          end
          curr = j
          break
        end
      end
    end

    -- add intervals for the connectors of merge children
    -- these are where we have multiple connector commit hashes
    -- for a single merge child, that is, more than one connector
    --
    -- TODO: this method presented here is probably universal and covers
    --       also for the previously computed intervals ... two birds one stone?
    do
      local low = #row.cells
      local high = 1
      for j = 1, #row.cells, 2 do
        local c = row.cells[j]
        if c.emphasis then
          if j > high then
            high = j
          end
          if j < low then
            low = j
          end
        end
      end

      if high > low then
        intervals[#intervals + 1] = { start = low, stop = high }
      end
    end

    if i % 2 == 0 then
      for _, interval in ipairs(intervals) do
        local a, b = interval.start, interval.stop
        for j = a + 1, b - 1 do
          local this = graph[i].cells[j]
          if this.connector == " " then
            this.connector = GHOR
          end
        end
      end
    end
  end

  -- print '---- stage 2 -------'

  -- insert symbols on connector rows
  --
  -- note that there are 8 possible connections
  -- under the assumption that any connector cell
  -- has at least 2 neighbors but no more than 3
  --
  -- there are 4 ways to make the connections of three neighbors
  -- there are 6 ways to make the connections of two neighbors
  -- however two of them are the vertical and horizontal connections
  -- that have already been taken care of
  --

  local symb_map = {
    -- two neighbors (no straights)
    -- - 8421
    [10] = GCLU, -- '1010'
    [9] = GCLD, -- '1001'
    [6] = GCRU, -- '0110'
    [5] = GCRD, -- '0101'
    -- three neighbors
    [14] = GLRU, -- '1110'
    [13] = GLRD, -- '1101'
    [11] = GLUD, -- '1011'
    [7] = GRUD, -- '0111'
  }

  for i = 2, #graph, 2 do
    local row = graph[i]
    local above = graph[i - 1]
    local below = graph[i + 1]

    for j = 1, #row.cells, 2 do
      local this = row.cells[j]

      if this.connector ~= GVER then
        local lc = row.cells[j - 1]
        local rc = row.cells[j + 1]
        local uc = above and above.cells[j]
        local dc = below and below.cells[j]

        local l = lc and (lc.connector ~= " " or lc.commit) or false
        local r = rc and (rc.connector ~= " " or rc.commit) or false
        local u = uc and (uc.connector ~= " " or uc.commit) or false
        local d = dc and (dc.connector ~= " " or dc.commit) or false

        -- number of neighbors
        local nn = 0

        local symb_n = 0
        for i, b in ipairs { l, r, u, d } do
          if b then
            nn = nn + 1
            symb_n = symb_n + bit.lshift(1, 4 - i)
          end
        end

        local symbol = symb_map[symb_n] or "?"

        if (i == #graph or i == #graph - 1) and symbol == "?" then
          symbol = GVER
        end

        local commit_dir_above = above.commit and above.commit.j == j

        ---@type 'l' | 'r' | nil -- placement of commit horizontally, only relevant if this is a connector row and if the cell is not immediately above or below the commit
        local clh_above = nil
        local commit_above = above.commit and above.commit.j ~= j
        if commit_above then
          clh_above = above.commit.j < j and "l" or "r"
        end

        if clh_above and symbol == GLRD then
          if clh_above == "l" then
            symbol = GLRDCL -- '<'
          elseif clh_above == "r" then
            symbol = GLRDCR -- '>'
          end
        elseif symbol == GLRU then
          -- because nothing else is possible with our
          -- current implicit graph building rules?
          symbol = GLRUCL -- '<'
        end

        local merge_dir_above = commit_dir_above and #above.commit.parents > 1

        if symbol == GLUD then
          symbol = merge_dir_above and GLUDCU or GLUDCD
        end

        if symbol == GRUD then
          symbol = merge_dir_above and GRUDCU or GRUDCD
        end

        if nn == 4 then
          symbol = merge_dir_above and GFORKD or GFORKU
        end

        if row.cells[j].commit then
          row.cells[j].connector = symbol
        end
      end
    end
  end

  local lines, highlights = graph_to_lines(graph)

  --
  -- BEGIN NEOGIT COMPATIBILITY CODE
  -- Transform graph into what neogit needs to render
  --
  local result = {}
  local hl = {}
  for _, highlight in ipairs(highlights) do
    local row = highlight.row
    if not hl[row] then
      hl[row] = {}
    end

    for i = highlight.start, highlight.stop do
      hl[row][i] = highlight
    end
  end

  for row, line in ipairs(lines) do
    local graph_row = {}
    local oid = line[1]
    local parts = line[2]

    for i, part in ipairs(parts) do
      local current_highlight = hl[row][i] or {}

      table.insert(graph_row, {
        oid = oid ~= "" and oid,
        text = part,
        color = not color and "Purple" or current_highlight.hg,
      })
    end

    if oid ~= "strip" then
      table.insert(result, graph_row)
    end
  end

  return result
end

return M
