local config = require("neogit.config")

local M = {}

local byte = string.byte
local sub = string.sub
local gsub = string.gsub
local diff = vim.diff

local PLUS = byte("+")
local MINUS = byte("-")
local SPACE = byte(" ")

-- same as delta's default: https://github.com/dandavison/delta/blob/12ef3ef0be4aebe0d2d2c810a426dbf314efa495/src/cli.rs#L594
local MAX_DISTANCE = 0.6

local diff_opts = { result_type = "indices", algorithm = "histogram" }

--- Convert strings to one-char-per-line for character-level diffing via vim.diff.
--- Returns the diff spans and a distance ratio (0.0 = identical, 1.0 = nothing in common).
---@param old string
---@param new string
---@return table old_spans
---@return table new_spans
---@return number distance
function M.char_diff_spans(old, new)
  local total = #old + #new
  if total == 0 or old == new then
    return {}, {}, 0
  end

  -- vim.diff with result_type = "indices" returns each hunk as a 4-element array:
  --   {old_start, old_count, new_start, new_count}.
  --
  --   - hunk[1] = where the change starts in the old string
  --   - hunk[2] = how many chars deleted (del)
  --   - hunk[3] = where the change starts in the new string
  --   - hunk[4] = how many chars inserted (ins)
  --
  -- stylua: ignore
  local result = diff(
    gsub(old, ".", "%0\n"),
    gsub(new, ".", "%0\n"),
    diff_opts
  )

  if not result then
    return {}, {}, 0
  end

  local old_spans, new_spans = {}, {}
  local changed = 0
  local idx_old, idx_new = 0, 0
  for i = 1, #result do
    local hunk = result[i]

    local del, ins = hunk[2], hunk[4]
    changed = changed + del + ins
    if del > 0 then
      if old_spans[idx_old] and old_spans[idx_old][2] == hunk[1] - 2 then
        old_spans[idx_old][2] = hunk[1] - 1 + del
      else
        idx_old = idx_old + 1
        old_spans[idx_old] = { hunk[1] - 1, hunk[1] - 1 + del }
      end
    end
    if ins > 0 then
      if new_spans[idx_new] and new_spans[idx_new][2] == hunk[3] - 2 then
        new_spans[idx_new][2] = hunk[3] - 1 + ins
      else
        idx_new = idx_new + 1
        new_spans[idx_new] = { hunk[3] - 1, hunk[3] - 1 + ins }
      end
    end
  end
  return old_spans, new_spans, changed / total
end

--- Apply treesitter syntax and word-level inline diff highlights to diff regions in a buffer.
---@param buf table Buffer instance
---@param regions table List of regions with first_line, last_line, filepath
function M.apply(buf, regions)
  local set_extmark = buf.set_extmark
  local ns = buf:create_namespace("NeogitDiffHighlight")

  local function apply_spans(bl, spans, hl)
    for _, span in ipairs(spans) do
      set_extmark(buf, ns, bl, span[1] + 1, {
        end_col = span[2] + 1,
        hl_group = hl,
        priority = 220,
      })
    end
  end

  for _, region in ipairs(regions) do
    local lines = buf:get_lines(region.first_line, region.last_line, false)
    local first_line = region.first_line

    local stripped = {}
    local buf_lines = {}
    local prefixes = {}
    local n = 0

    for i, line in ipairs(lines) do
      local b = byte(line, 1)
      if b == PLUS or b == MINUS or b == SPACE then
        n = n + 1
        stripped[n] = sub(line, 2)
        buf_lines[n] = first_line + i - 1
        prefixes[n] = b
      end
    end

    if n ~= 0 then
      -- Treesitter syntax highlights
      if config.values.treesitter_diff_highlight then
        do
          local ft = vim.filetype.match { filename = region.filepath:match("-> (.+)$") or region.filepath }
          local lang = ft and vim.treesitter.language.get_lang(ft)

          if lang then
            local source = table.concat(stripped, "\n")
            local ts_parser = vim.treesitter.get_string_parser(source, lang)
            ts_parser:parse()
            ts_parser:for_each_tree(function(tree, ltree)
              local query = vim.treesitter.query.get(ltree:lang(), "highlights")
              if not query then
                return
              end

              local captures = query.captures
              for id, node in query:iter_captures(tree:root(), source) do
                local sr, sc, er, ec = node:range()
                for row = sr, er do
                  local bl = buf_lines[row + 1]
                  if bl then
                    set_extmark(buf, ns, bl, (row == sr and sc or 0) + 1, {
                      end_col = (row == er and ec or #stripped[row + 1]) + 1,
                      hl_group = "@" .. captures[id],
                      priority = 210,
                    })
                  end
                end
              end
            end)
          end
        end
      end

      -- Word-level inline diff highlights
      if config.values.word_diff_highlight then
        do
          local i = 1
          while i <= n do
            local del_start = i
            while i <= n and prefixes[i] == MINUS do
              i = i + 1
            end

            local add_start = i
            while i <= n and prefixes[i] == PLUS do
              i = i + 1
            end

            local del_count = add_start - del_start
            local add_count = i - add_start

            for j = 0, math.min(del_count, add_count) - 1 do
              -- stylua: ignore
              local old_spans, new_spans, distance = M.char_diff_spans(
                stripped[del_start + j],
                stripped[add_start + j]
              )

              if distance <= MAX_DISTANCE then
                apply_spans(buf_lines[del_start + j], old_spans, "NeogitDiffDeleteInline")
                apply_spans(buf_lines[add_start + j], new_spans, "NeogitDiffAddInline")
              end
            end

            if del_count == 0 and add_count == 0 then
              i = i + 1
            end
          end
        end
      end
    end
  end
end

return M
