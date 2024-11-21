-- Modified version of graphing algorithm from https://github.com/rbong/vim-flog

local M = {}

local graph_error = "flog: internal error drawing graph"

-- stylua: ignore start
local current_commit_str        = "• "
local commit_branch_str         = "│ "
local commit_empty_str          = "  "
local complex_merge_str_1       = "┬┊"
local complex_merge_str_2       = "╰┤"
local merge_all_str             = "┼"
local merge_jump_str            = "┊"
local merge_up_down_left_str    = "┤"
local merge_up_down_right_str   = "├"
local merge_up_down_str         = "│"
local merge_up_left_right_str   = "┴"
local merge_up_left_str         = "╯"
local merge_up_right_str        = "╰"
local merge_up_str              = " "
local merge_down_left_right_str = "┬"
local merge_down_left_str       = "╮"
local merge_down_right_str      = "╭"
local merge_left_right_str      = "─"
local merge_empty_str           = " "
local missing_parent_str        = "┊ "
local missing_parent_branch_str = "│ "
local missing_parent_empty_str  = "  "

-- Returns an iterator for traversing UTF-8 encoded strings, yielding each
-- character as a substring. The iterator ensures correct handling of
-- multi-byte UTF-8 characters, decoding them and returning them as separate
-- characters.
-- 
-- See also: 
-- https://github.com/gijit/gi/blob/7052cfb07ca8b52afaa6c2a3deee53952784bd5d/pkg/utf8/utf8.lua#L80C1-L81C47
--
local function utf8_iter(s)
  local i = 1
  return function()
    local b = string.byte(s, i)

    if not b then
      return nil -- string end
    end

    -- {{{
    -- 00000000-01111111 	00-7F 	000-127 	US-ASCII (single byte)
    -- 10000000-10111111 	80-BF 	128-191 	Second, third, or fourth byte of a multi-byte sequence
    -- 11000000-11000001 	C0-C1 	192-193 	Overlong encoding: start of a 2-byte sequence, but code point <= 127
    -- 11000010-11011111 	C2-DF 	194-223 	Start of 2-byte sequence
    -- 11100000-11101111 	E0-EF 	224-239 	Start of 3-byte sequence
    -- 11110000-11110100 	F0-F4 	240-244 	Start of 4-byte sequence
    -- 11110101-11110111 	F5-F7 	245-247 	Restricted by RFC 3629: start of 4-byte sequence for codepoint above 10FFFF
    -- 11111000-11111011 	F8-FB 	248-251 	Restricted by RFC 3629: start of 5-byte sequence
    -- 11111100-11111101 	FC-FD 	252-253 	Restricted by RFC 3629: start of 6-byte sequence
    -- 11111110-11111111 	FE-FF 	254-255 	Invalid: not defined by original UTF-8 specification
    -- }}}
    local w = (b >= 192 and b <= 223 and 2) or
              (b >= 224 and b <= 239 and 3) or
              (b >= 240 and b <= 247 and 4) or 1

    local c = string.sub(s, i, i + w - 1)
    i = i + w
    return c
  end
end
-- stylua: ignore end

function M.build(commits)
  commits = require("neogit.lib.util").filter_map(commits, function(item)
    if item.oid then
      return item
    end
  end)

  -- Init commit parsing data
  local commit_hashes = {}
  for _, commit in ipairs(commits) do
    commit_hashes[commit.oid] = 1
  end

  local vim_out = {}
  local vim_out_index = 1

  -- Init graph data
  local branch_hashes = {}
  local branch_indexes = {}
  local nbranches = 0

  -- Draw graph
  for _, commit in ipairs(commits) do
    -- Get commit data
    local commit_hash = commit.oid
    local parents = vim.split(commit.parent, " ")
    local parent_hashes = {}
    local nparents = #parents

    for _, parent in ipairs(parents) do
      parent_hashes[parent] = 1
    end

    -- Init commit output

    -- The prefix that goes before the first commit line
    local commit_prefix = {}
    -- The number of strings in commit lines
    local ncommit_strings = 0
    -- The merge line that goes after the commit
    local merge_line = {}
    -- The complex merge line that goes after the merge
    local complex_merge_line = {}
    -- The number of strings in merge lines
    local nmerge_strings = 0
    -- The two lines indicating missing parents after the complex line
    local missing_parents_line_1 = {}
    local missing_parents_line_2 = {}
    -- The number of strings in missing parent lines
    local nmissing_parents_strings = 0

    -- Init visual data

    -- The number of columns in the commit output
    local ncommit_cols = 0
    -- The number of visual parents
    local nvisual_parents = 0
    -- The number of complex merges (octopus)
    local ncomplex_merges = 0
    -- The number of missing parents
    local nmissing_parents = 0

    -- Init graph data

    -- The number of passed merges
    local nmerges_left = 0
    -- The number of upcoming merges (parents + commit)
    local nmerges_right = nparents + 1
    -- The index of the commit branch
    local commit_branch_index = branch_indexes[commit_hash]
    -- The index of the moved parent branch (there is only one)
    local moved_parent_branch_index = nil
    -- The number of branches on the commit line
    local ncommit_branches = nbranches + (commit_branch_index and 0 or 1)

    -- Init indexes

    -- The current branch
    local branch_index = 1
    -- The current parent
    local parent_index = 1

    -- Find the first empty parent
    while parent_index <= nparents and branch_indexes[parents[parent_index]] do
      parent_index = parent_index + 1
    end

    -- Traverse old and new branches

    while branch_index <= nbranches or nmerges_right > 0 do
      -- Get branch data

      local branch_hash = branch_hashes[branch_index]
      local is_commit = branch_index == commit_branch_index

      -- Set merge info before updates

      local merge_up = branch_hash or moved_parent_branch_index == branch_index
      local merge_left = nmerges_left > 0 and nmerges_right > 0
      local is_complex = false
      local is_missing_parent = false

      -- Handle commit

      if not branch_hash and not commit_branch_index then
        -- Found empty branch and commit does not have a branch
        -- Add the commit in the empty spot

        commit_branch_index = branch_index
        is_commit = true
      end

      if is_commit then
        -- Count commit merge
        nmerges_right = nmerges_right - 1
        nmerges_left = nmerges_left + 1

        if branch_hash then
          -- End of branch

          -- Remove branch
          branch_hashes[commit_branch_index] = nil
          branch_indexes[commit_hash] = nil

          -- Trim trailing empty branches
          while nbranches > 0 and not branch_hashes[nbranches] do
            nbranches = nbranches - 1
          end

          -- Clear branch hash
          branch_hash = nil
        end

        if parent_index > nparents and nmerges_right == 1 then
          -- There is only one remaining parent, to the right
          -- Move it under the commit

          -- Find parent to right
          parent_index = nparents
          while (branch_indexes[parents[parent_index]] or -1) < branch_index do
            parent_index = parent_index - 1
          end

          -- Get parent data
          local parent_hash = parents[parent_index]
          local parent_branch_index = branch_indexes[parent_hash]

          -- Remove old parent branch
          branch_hashes[parent_branch_index] = nil
          branch_indexes[parent_hash] = nil

          -- Trim trailing empty branches
          while nbranches > 0 and not branch_hashes[nbranches] do
            nbranches = nbranches - 1
          end

          -- Record the old index
          moved_parent_branch_index = parent_branch_index

          -- Count upcoming moved parent as another merge
          nmerges_right = nmerges_right + 1
        end
      end

      -- Handle parents

      if not branch_hash and parent_index <= nparents then
        -- New parent

        -- Get parent data
        local parent_hash = parents[parent_index]

        -- Set branch to parent
        branch_indexes[parent_hash] = branch_index
        branch_hashes[branch_index] = parent_hash

        -- Update branch has
        branch_hash = parent_hash

        -- Update the number of branches
        if branch_index > nbranches then
          nbranches = branch_index
        end

        -- Jump to next available parent
        parent_index = parent_index + 1
        while parent_index <= nparents and branch_indexes[parents[parent_index]] do
          parent_index = parent_index + 1
        end

        -- Count new parent merge
        nmerges_right = nmerges_right - 1
        nmerges_left = nmerges_left + 1

        -- Determine if parent is missing
        if branch_hash and not commit_hashes[parent_hash] then
          is_missing_parent = true
          nmissing_parents = nmissing_parents + 1
        end

        -- Record the visual parent
        nvisual_parents = nvisual_parents + 1
      elseif
        branch_index == moved_parent_branch_index or (nmerges_right > 0 and parent_hashes[branch_hash])
      then
        -- Existing parents

        -- Count existing parent merge
        nmerges_right = nmerges_right - 1
        nmerges_left = nmerges_left + 1

        -- Determine if parent has a complex merge
        is_complex = merge_left and nmerges_right > 0
        if is_complex then
          ncomplex_merges = ncomplex_merges + 1
        end

        -- Determine if parent is missing
        if branch_hash and not commit_hashes[branch_hash] then
          is_missing_parent = true
          nmissing_parents = nmissing_parents + 1
        end

        if branch_index ~= moved_parent_branch_index then
          -- Record the visual parent
          nvisual_parents = nvisual_parents + 1
        end
      end

      -- Draw commit lines

      if branch_index <= ncommit_branches then
        -- Update commit visual info

        ncommit_cols = ncommit_cols + 2
        ncommit_strings = ncommit_strings + 1

        if is_commit then
          -- Draw current commit

          commit_prefix[ncommit_strings] = current_commit_str
        elseif merge_up then
          -- Draw unrelated branch

          commit_prefix[ncommit_strings] = commit_branch_str
        else
          -- Draw empty branch

          commit_prefix[ncommit_strings] = commit_empty_str
        end
      end

      -- Update merge visual info

      nmerge_strings = nmerge_strings + 1

      -- Draw merge lines

      if is_complex then
        -- Draw merge lines for complex merge

        merge_line[nmerge_strings] = complex_merge_str_1
        complex_merge_line[nmerge_strings] = complex_merge_str_2
      else
        -- Draw non-complex merge lines

        -- Update merge info after drawing commit

        merge_up = merge_up or is_commit or branch_index == moved_parent_branch_index
        local merge_right = nmerges_left > 0 and nmerges_right > 0

        -- Draw left character

        if branch_index > 1 then
          if merge_left then
            -- Draw left merge line
            merge_line[nmerge_strings] = merge_left_right_str
          else
            -- No merge to left
            -- Draw empty space
            merge_line[nmerge_strings] = merge_empty_str
          end
          -- Complex merge line always has empty space here
          complex_merge_line[nmerge_strings] = merge_empty_str

          -- Update visual merge info

          nmerge_strings = nmerge_strings + 1
        end

        -- Draw right character

        if merge_up then
          if branch_hash then
            if merge_left then
              if merge_right then
                if is_commit then
                  -- Merge up, down, left, right
                  merge_line[nmerge_strings] = merge_all_str
                else
                  -- Jump over
                  merge_line[nmerge_strings] = merge_jump_str
                end
              else
                -- Merge up, down, left
                merge_line[nmerge_strings] = merge_up_down_left_str
              end
            else
              if merge_right then
                -- Merge up, down, right
                merge_line[nmerge_strings] = merge_up_down_right_str
              else
                -- Merge up, down
                merge_line[nmerge_strings] = merge_up_down_str
              end
            end
          else
            if merge_left then
              if merge_right then
                -- Merge up, left, right
                merge_line[nmerge_strings] = merge_up_left_right_str
              else
                -- Merge up, left
                merge_line[nmerge_strings] = merge_up_left_str
              end
            else
              if merge_right then
                -- Merge up, right
                merge_line[nmerge_strings] = merge_up_right_str
              else
                -- Merge up
                merge_line[nmerge_strings] = merge_up_str
              end
            end
          end
        else
          if branch_hash then
            if merge_left then
              if merge_right then
                -- Merge down, left, right
                merge_line[nmerge_strings] = merge_down_left_right_str
              else
                -- Merge down, left
                merge_line[nmerge_strings] = merge_down_left_str
              end
            else
              if merge_right then
                -- Merge down, right
                merge_line[nmerge_strings] = merge_down_right_str
              else
                -- Merge down
                -- Not possible to merge down only
                error(graph_error)
              end
            end
          else
            if merge_left then
              if merge_right then
                -- Merge left, right
                merge_line[nmerge_strings] = merge_left_right_str
              else
                -- Merge left
                -- Not possible to merge left only
                error(graph_error)
              end
            else
              if merge_right then
                -- Merge right
                -- Not possible to merge right only
                error(graph_error)
              else
                -- No merges
                merge_line[nmerge_strings] = merge_empty_str
              end
            end
          end
        end

        -- Draw complex right char

        if branch_hash then
          complex_merge_line[nmerge_strings] = merge_up_down_str
        else
          complex_merge_line[nmerge_strings] = merge_empty_str
        end
      end

      -- Update visual missing parents info

      nmissing_parents_strings = nmissing_parents_strings + 1

      -- Draw missing parents lines

      if is_missing_parent then
        missing_parents_line_1[nmissing_parents_strings] = missing_parent_str
        missing_parents_line_2[nmissing_parents_strings] = missing_parent_empty_str
      elseif branch_hash then
        missing_parents_line_1[nmissing_parents_strings] = missing_parent_branch_str
        missing_parents_line_2[nmissing_parents_strings] = missing_parent_branch_str
      else
        missing_parents_line_1[nmissing_parents_strings] = missing_parent_empty_str
        missing_parents_line_2[nmissing_parents_strings] = missing_parent_empty_str
      end

      -- Remove missing parent

      if is_missing_parent and branch_index ~= moved_parent_branch_index then
        -- Remove branch
        branch_hashes[branch_index] = nil
        assert(branch_hash, "no branch hash")
        branch_indexes[branch_hash] = nil

        -- Trim trailing empty branches
        while nbranches > 0 and not branch_hashes[nbranches] do
          nbranches = nbranches - 1
        end
      end

      -- Increment

      branch_index = branch_index + 1
    end

    -- Output

    -- Calculate whether certain lines should be outputted

    local should_out_merge = (
      nparents > 1
      or moved_parent_branch_index
      or (nparents == 0 and nbranches == 0)
      or (nparents == 1 and branch_indexes[parents[1]] ~= commit_branch_index)
    )

    local should_out_complex = should_out_merge and ncomplex_merges > 0
    local should_out_missing_parents = nmissing_parents > 0

    -- Initialize commit objects
    -- local vim_commit_body = {}
    local vim_commit_suffix = {}
    local vim_commit_suffix_index = 1

    vim_out[vim_out_index] = { text = table.concat(commit_prefix, ""), color = "Purple", oid = commit_hash }
    vim_out_index = vim_out_index + 1

    -- Add merge lines
    if should_out_merge then
      vim_commit_suffix[vim_commit_suffix_index] = table.concat(merge_line, "")
      vim_out[vim_out_index] = { text = vim_commit_suffix[vim_commit_suffix_index], color = "Purple" }

      vim_out_index = vim_out_index + 1
      vim_commit_suffix_index = vim_commit_suffix_index + 1

      if should_out_complex then
        vim_commit_suffix[vim_commit_suffix_index] = table.concat(complex_merge_line, "")
        vim_out[vim_out_index] = { text = vim_commit_suffix[vim_commit_suffix_index], color = "Purple" }

        vim_out_index = vim_out_index + 1
        vim_commit_suffix_index = vim_commit_suffix_index + 1
      end
    end

    -- Add missing parents lines
    if should_out_missing_parents then
      vim_commit_suffix[vim_commit_suffix_index] = table.concat(missing_parents_line_1, "")
      vim_out[vim_out_index] = { text = vim_commit_suffix[vim_commit_suffix_index], color = "Purple" }

      vim_out_index = vim_out_index + 1
      vim_commit_suffix_index = vim_commit_suffix_index + 1

      vim_commit_suffix[vim_commit_suffix_index] = table.concat(missing_parents_line_2, "")
      vim_out[vim_out_index] = { text = vim_commit_suffix[vim_commit_suffix_index], color = "Purple" }

      vim_out_index = vim_out_index + 1
      vim_commit_suffix_index = vim_commit_suffix_index + 1
    end
  end

  local graph = {}
  for _, line in ipairs(vim_out) do
    local g = {}
    for c in utf8_iter(line.text) do
      table.insert(g, { text = c, color = line.color, oid = line.oid })
    end
    table.insert(graph, g)
  end

  return graph
end

return M
