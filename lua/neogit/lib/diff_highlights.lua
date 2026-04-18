local config = require("neogit.config")

local M = {}

local byte = string.byte
local sub = string.sub
local diff = vim.text.diff or vim.diff

local PLUS = byte("+")
local MINUS = byte("-")
local SPACE = byte(" ")

-- same as delta's default: https://github.com/dandavison/delta/blob/12ef3ef0be4aebe0d2d2c810a426dbf314efa495/src/cli.rs#L594
local MAX_DISTANCE = 0.6

local diff_opts = { result_type = "indices", algorithm = "histogram" }

--- Split a string into word and non-word tokens, returning a list of {start, end} byte ranges.
--- Positions are 0-indexed; end is exclusive. Tokens alternate between \w+ and \W+ runs.
---@param s string
---@return table tokens  List of {start_byte, end_byte} pairs (0-indexed, end exclusive)
local function tokenize(s)
  local tokens = {}
  local i = 1
  local len = #s
  while i <= len do
    local is_word = sub(s, i, i):match("%w") ~= nil
    local j = i + 1
    while j <= len do
      if (sub(s, j, j):match("%w") ~= nil) ~= is_word then
        break
      end
      j = j + 1
    end
    tokens[#tokens + 1] = { i - 1, j - 1 }
    i = j
  end
  return tokens
end

--- Merge adjacent spans that are separated by a single underscore character.
--- This handles identifiers like `foo_bar` where the diff splits on the `_`.
---@param spans table  List of {start_byte, end_byte} pairs (0-indexed, end exclusive)
---@param s string     The original string the spans index into
---@return table
local function merge_underscore_spans(spans, s)
  if #spans < 2 then
    return spans
  end
  local merged = { spans[1] }
  for i = 2, #spans do
    local prev = merged[#merged]
    local curr = spans[i]
    -- gap == 1 means exactly one byte separates the two spans
    if curr[1] - prev[2] == 1 and sub(s, prev[2] + 1, prev[2] + 1) == "_" then
      merged[#merged] = { prev[1], curr[2] }
    else
      merged[#merged + 1] = curr
    end
  end
  return merged
end

--- Diff two strings at word granularity via vim.text.diff
--- Tokens are \w+ (word) and \W+ (non-word) runs. Each token becomes one diff line.
--- Returns the changed spans and a distance ratio (0.0 = identical, 1.0 = nothing in common).
---
--- vim.diff with result_type = "indices" returns each hunk as a 4-element array:
---   {old_start, old_count, new_start, new_count}  (all 1-based).
---@param old string
---@param new string
---@return table old_spans  List of {start_byte, end_byte} pairs (0-indexed, end exclusive)
---@return table new_spans
---@return number distance
function M.word_diff_spans(old, new)
  if #old + #new == 0 or old == new then
    return {}, {}, 0
  end

  local old_tokens = tokenize(old)
  local new_tokens = tokenize(new)
  local n_old = #old_tokens
  local n_new = #new_tokens
  local total_tokens = n_old + n_new

  -- An empty token list produces a phantom empty line in vim.diff input that
  -- causes out-of-bounds hunk indices.  Nothing meaningful to highlight.
  if n_old == 0 or n_new == 0 then
    return {}, {}, 1
  end

  local old_parts = {}
  for k, t in ipairs(old_tokens) do
    old_parts[k] = sub(old, t[1] + 1, t[2])
  end
  local new_parts = {}
  for k, t in ipairs(new_tokens) do
    new_parts[k] = sub(new, t[1] + 1, t[2])
  end

  -- stylua: ignore
  local result = diff(
    table.concat(old_parts, "\n") .. "\n",
    table.concat(new_parts, "\n") .. "\n",
    diff_opts
  )

  if not result then
    return {}, {}, 0
  end

  local old_spans, new_spans = {}, {}
  local changed = 0

  for _, hunk in ipairs(result) do
    local del, ins = hunk[2], hunk[4]
    changed = changed + del + ins

    if del > 0 and hunk[1] + del - 1 <= n_old then
      -- Merge contiguous token runs into a single byte span
      old_spans[#old_spans + 1] = { old_tokens[hunk[1]][1], old_tokens[hunk[1] + del - 1][2] }
    end
    if ins > 0 and hunk[3] + ins - 1 <= n_new then
      new_spans[#new_spans + 1] = { new_tokens[hunk[3]][1], new_tokens[hunk[3] + ins - 1][2] }
    end
  end

  old_spans = merge_underscore_spans(old_spans, old)
  new_spans = merge_underscore_spans(new_spans, new)

  return old_spans, new_spans, changed / total_tokens
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

          if lang and pcall(vim.treesitter.language.inspect, lang) then
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
              local old_spans, new_spans, distance = M.word_diff_spans(
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
