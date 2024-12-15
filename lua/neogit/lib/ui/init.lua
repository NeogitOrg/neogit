local Component = require("neogit.lib.ui.component")
local util = require("neogit.lib.util")
local Renderer = require("neogit.lib.ui.renderer")
local Collection = require("neogit.lib.collection")
local logger = require("neogit.logger") -- TODO: Add logging

---@class Section
---@field items  StatusItem[]
---@field name string
---@field first number

---@class Selection
---@field sections Section[]
---@field first_line number
---@field last_line number
---@field section Section|nil
---@field item StatusItem|nil
---@field commit CommitLogEntry|nil
---@field commits  CommitLogEntry[]
---@field items  StatusItem[]
local Selection = {}
Selection.__index = Selection

---@class UiComponent
---@field tag string
---@field options table Component props or arguments
---@field children UiComponent[]

---@class FindOptions

---@class Ui
---@field buf Buffer
---@field layout table
local Ui = {}
Ui.__index = Ui

---@param buf Buffer
---@return Ui
function Ui.new(buf)
  return setmetatable({ buf = buf, layout = {} }, Ui)
end

function Ui._find_component(components, f, options)
  for _, c in ipairs(components) do
    if c.tag == "col" or c.tag == "row" then
      local res = Ui._find_component(c.children, f, options)

      if res then
        return res
      end
    end

    if f(c) then
      return c
    end
  end

  return nil
end

---@param f fun(c: UiComponent): boolean
---@param options FindOptions|nil
function Ui:find_component(f, options)
  return Ui._find_component(self.layout, f, options or {})
end

function Ui._find_components(components, f, result, options)
  for _, c in ipairs(components) do
    if c.tag == "col" or c.tag == "row" then
      Ui._find_components(c.children, f, result, options)
    end

    if f(c) then
      table.insert(result, c)
    end
  end
end

function Ui:find_components(f, options)
  local result = {}
  Ui._find_components(self.layout, f, result, options or {})
  return result
end

---@param fn? fun(c: Component): boolean
---@return Component|nil
function Ui:get_component_under_cursor(fn)
  fn = fn or function()
    return true
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  return self:get_component_on_line(line, fn)
end

---@param line integer
---@param fn fun(c: Component): boolean
---@return Component|nil
function Ui:get_component_on_line(line, fn)
  return self:_find_component_by_index(line, fn)
end

---@param line integer
---@param f fun(c: Component): boolean
---@return Component|nil
function Ui:_find_component_by_index(line, f)
  local node = self.node_index:find_by_line(line)[1]
  while node do
    if f(node) then
      return node
    end

    node = node.parent
  end
end

---@param oid string
---@return Component|nil
function Ui:find_component_by_oid(oid)
  return self.node_index:find_by_oid(oid)
end

---@return Component|nil
function Ui:get_cursor_context(line)
  local cursor = line or vim.api.nvim_win_get_cursor(0)[1]
  return self:_find_component_by_index(cursor, function(node)
    return node.options.context
  end)
end

---@return string|nil
function Ui:get_line_highlight(line)
  local component = self:_find_component_by_index(line, function(node)
    return node.options.line_hl ~= nil
  end)

  return component and component.options.line_hl
end

---@return Component|nil
function Ui:get_interactive_component_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)

  return self:_find_component_by_index(cursor[1], function(node)
    return node.options.interactive
  end)
end

---@return Component|nil
function Ui:get_fold_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)

  return self:_find_component_by_index(cursor[1], function(node)
    return node.options.foldable
  end)
end

---@class SelectedHunk: Hunk
---@field from number start offset from the first line of the hunk
---@field to number end offset from the first line of the hunk
---@field lines string[]
---
---@param item StatusItem
---@param first_line number
---@param last_line number
---@param partial boolean
---@return SelectedHunk[]
function Ui:item_hunks(item, first_line, last_line, partial)
  local hunks = {}

  -- TODO: Move this to lib.git.diff
  -- local diff = require("neogit.lib.git").cli.diff.check.call { hidden = true, ignore_error = true }
  -- local conflict_markers = {}
  -- if diff.code == 2 then
  --   for _, out in ipairs(diff.stdout) do
  --     local line = string.gsub(out, "^" .. item.name .. ":", "")
  --     if line ~= out and string.match(out, "conflict") then
  --       table.insert(conflict_markers, tonumber(string.match(line, "%d+")))
  --     end
  --   end
  -- end

  if not item.folded and item.diff.hunks then
    for _, h in ipairs(item.diff.hunks) do
      if h.first <= first_line and h.last >= last_line then
        local from, to

        if partial then
          local length = last_line - first_line

          from = first_line - h.first
          to = from + length
        else
          from = h.diff_from + 1
          to = h.diff_to
        end

        -- local conflict = false
        -- for _, n in ipairs(conflict_markers) do
        --   if from <= n and n <= to then
        --     conflict = true
        --     break
        --   end
        -- end

        local o = {
          from = from,
          to = to,
          __index = h,
          hunk = h,
          -- conflict = conflict,
        }

        setmetatable(o, o)

        table.insert(hunks, o)
      end
    end
  end

  return hunks
end

function Ui:get_selection()
  local visual_pos = vim.fn.line("v")
  local cursor_pos = vim.fn.line(".")

  local first_line = math.min(visual_pos, cursor_pos)
  local last_line = math.max(visual_pos, cursor_pos)

  local res = {
    sections = {},
    first_line = first_line,
    last_line = last_line,
    item = nil,
    commit = nil,
    commits = {},
    items = {},
  }

  for _, section in ipairs(self.item_index) do
    local items = {}

    if not section.first or section.first > last_line then
      break
    end

    if section.last >= first_line then
      if section.first <= first_line and section.last >= last_line then
        res.section = section
      end

      local entire_section = section.first == first_line and first_line == last_line

      for _, item in pairs(section.items) do
        if entire_section or item.first <= last_line and item.last >= first_line then
          if not res.item and item.first <= first_line and item.last >= last_line then
            res.item = item

            res.commit = item.commit
          end

          if item.commit then
            table.insert(res.commits, item.commit)
          end

          table.insert(res.items, item)
          table.insert(items, item)
        end
      end

      local section = {
        section = section,
        items = items,
        __index = section,
      }

      setmetatable(section, section)
      table.insert(res.sections, section)
    end
  end

  return setmetatable(res, Selection)
end

---@return string[]
function Ui:get_commits_in_selection()
  local range = { vim.fn.getpos("v")[2], vim.fn.getpos(".")[2] }
  table.sort(range)
  local start, stop = unpack(range)

  local commits = {}
  for i = start, stop do
    local component = self:_find_component_by_index(i, function(node)
      return node.options.oid ~= nil
    end)

    if component then
      table.insert(commits, 1, component.options.oid)
    end
  end

  return util.deduplicate(commits)
end

---@return string[]
function Ui:get_filepaths_in_selection()
  local range = { vim.fn.getpos("v")[2], vim.fn.getpos(".")[2] }
  table.sort(range)
  local start, stop = unpack(range)

  local paths = {}
  for i = start, stop do
    local component = self:_find_component_by_index(i, function(node)
      return node.options.item ~= nil and node.options.item.escaped_path
    end)

    if component then
      table.insert(paths, 1, component.options.item.escaped_path)
    end
  end

  return util.deduplicate(paths)
end

---@return string|nil
function Ui:get_commit_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local component = self:_find_component_by_index(cursor[1], function(node)
    return node.options.oid ~= nil
  end)

  return component and component.options.oid
end

---@return ParsedRef|nil
function Ui:get_ref_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local component = self:_find_component_by_index(cursor[1], function(node)
    return node.options.ref ~= nil
  end)

  return component and component.options.ref
end

---@return string|nil
function Ui:get_yankable_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local component = self:_find_component_by_index(cursor[1], function(node)
    return node.options.yankable ~= nil
  end)

  return component and component.options.yankable
end

---@return Section|nil
function Ui:first_section()
  return self.item_index[1]
end

---@return Component|nil
function Ui:get_current_section(line)
  line = line or vim.api.nvim_win_get_cursor(0)[1]
  local component = self:_find_component_by_index(line, function(node)
    return node.options.section ~= nil
  end)

  return component
end

---@class CursorLocation
---@field first number
---@field last number
---@field section {index: number, name: string}|nil
---@field file {index: number, name: string}|nil
---@field hunk {index: number, name: string, index_from: number}|nil
---@field section_offset number|nil
---@field hunk_offset number|nil

---Encode the cursor location into a table
---@param line number?
---@return CursorLocation
function Ui:get_cursor_location(line)
  line = line or vim.api.nvim_win_get_cursor(0)[1]
  local section_loc, section_offset, file_loc, hunk_loc, first, last, hunk_offset

  for li, loc in ipairs(self.item_index) do
    if line == loc.first then
      section_loc = { index = li, name = loc.name }
      first, last = loc.first, loc.last

      break
    elseif loc.first and line >= loc.first and line <= loc.last then
      section_loc = { index = li, name = loc.name }

      if #loc.items > 0 then
        for fi, file in ipairs(loc.items) do
          if line == file.first then
            file_loc = { index = fi, name = file.name }
            first, last = file.first, file.last

            break
          elseif line >= file.first and line <= file.last then
            file_loc = { index = fi, name = file.name }

            for hi, hunk in ipairs(file.diff.hunks) do
              if line >= hunk.first and line <= hunk.last then
                hunk_loc = { index = hi, name = hunk.hash, index_from = hunk.index_from }
                first, last = hunk.first, hunk.last

                if line > hunk.first then
                  hunk_offset = line - hunk.first
                end

                break
              end
            end

            break
          end
        end
      else
        section_offset = line - loc.first
      end

      break
    end
  end

  return {
    section = section_loc,
    file = file_loc,
    hunk = hunk_loc,
    first = first,
    last = last,
    section_offset = section_offset,
    hunk_offset = hunk_offset,
  }
end

---@param cursor CursorLocation
---@return number
function Ui:resolve_cursor_location(cursor)
  if #self.item_index == 0 then
    logger.debug("[UI] No items to resolve cursor location")
    return 1
  end

  if not cursor.section then
    logger.debug("[UI] No Cursor Section")
    cursor.section = { index = 1, name = "" }
  end

  local section = Collection.new(self.item_index):find(function(s)
    return s.name == cursor.section.name
  end)

  if not section then
    logger.debug("[UI] No Section Found '" .. cursor.section.name .. "'")

    cursor.file = nil
    cursor.hunk = nil
    section = self.item_index[math.min(cursor.section.index, #self.item_index)]
  end

  if not cursor.file or not section.items or #section.items == 0 then
    if cursor.section_offset then
      logger.debug("[UI] No file - using section.first with offset")
      return section.first + cursor.section_offset
    else
      logger.debug("[UI] No file - using section.first")
      return section.first
    end
  end

  local file = Collection.new(section.items):find(function(f)
    return f.name == cursor.file.name
  end)

  if not file then
    logger.debug(("[UI] No file found %q"):format(cursor.file.name))

    cursor.hunk = nil
    file = section.items[math.min(cursor.file.index, #section.items)]
  end

  if not cursor.hunk or not file.diff.hunks or #file.diff.hunks == 0 then
    logger.debug("[UI] No hunk - using file.first")
    return file.first
  end

  local hunk = Collection.new(file.diff.hunks):find(function(h)
    return h.hash == cursor.hunk.name
  end) or file.diff.hunks[math.min(cursor.hunk.index, #file.diff.hunks)]

  if cursor.hunk.index_from == hunk.index_from then
    logger.debug(("[UI] Using hunk.first with offset %q"):format(cursor.hunk.name))
    return hunk.first + (cursor.hunk_offset or 0) - (cursor.last - hunk.last)
  else
    logger.debug(("[UI] Using hunk.first %q"):format(cursor.hunk.name))
    return hunk.first
  end
end

---@return table|nil
function Ui:get_hunk_or_filename_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local component = self:_find_component_by_index(cursor[1], function(node)
    return node.options.hunk ~= nil or node.options.filename ~= nil
  end)

  return component and {
    hunk = component.options.hunk,
    filename = component.options.filename,
  }
end

---@return table|nil
function Ui:get_item_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local component = self:_find_component_by_index(cursor[1], function(node)
    return node.options.item ~= nil
  end)

  return component and component.options.item
end

---@param layout table
---@return table[]
local function filter_layout(layout)
  return util.filter(layout, function(x)
    return type(x) == "table"
  end)
end

local function node_prefix(node, prefix)
  local base = false
  local key
  if node.options.section then
    key = node.options.section
  elseif node.options.filename then
    key = node.options.filename
  elseif node.options.hunk then
    base = true
    key = node.options.hunk.hash
  end

  if key then
    return ("%s--%s"):format(prefix, key), base
  else
    return nil, base
  end
end

---@param node table
---@param node_table? table
---@param prefix? string
---@return table
local function folded_node_state(node, node_table, prefix)
  if not node_table then
    node_table = {}
  end

  prefix = prefix or ""

  local key, base = node_prefix(node, prefix)
  if key then
    prefix = key
    node_table[prefix] = { folded = node.options.folded }
  end

  if node.children and not base then
    for _, child in ipairs(node.children) do
      folded_node_state(child, node_table, prefix)
    end
  end

  return node_table
end

function Ui:_update_fold_state(node, attributes, prefix)
  prefix = prefix or ""

  local key, base = node_prefix(node, prefix)
  if key then
    prefix = key

    if attributes[prefix] then
      node.options.folded = attributes[prefix].folded
    end
  end

  if node.children and not base then
    for _, child in ipairs(node.children) do
      self:_update_fold_state(child, attributes, prefix)
    end
  end
end

function Ui:_update_on_open(node, attributes, prefix)
  prefix = prefix or ""

  local key, base = node_prefix(node, prefix)
  if key then
    prefix = key

    -- TODO: If a hunk is closed, it will be re-opened on update because the on_open callback runs async :\
    if attributes[prefix] then
      if node.options.on_open and not attributes[prefix].folded then
        node.options.on_open(node, self, prefix)
      end
    end
  end

  if node.children and not base then
    for _, child in ipairs(node.children) do
      self:_update_on_open(child, attributes, prefix)
    end
  end
end

---@return table
function Ui:get_fold_state()
  return folded_node_state(self.layout)
end

---@param state table
function Ui:set_fold_state(state)
  self._node_fold_state = state
  self:update()
end

function Ui:render(...)
  local layout = filter_layout { ... }
  local root = Component.new(function()
    return { tag = "_root", children = layout }
  end)()

  if not vim.tbl_isempty(self.layout) then
    self._node_fold_state = folded_node_state(self.layout)
  end

  self.layout = root
  self:update()
end

function Ui:update()
  -- Copy over the old fold state _before_ buffer is rendered so the output of the fold buffer is correct
  if self._node_fold_state then
    self:_update_fold_state(self.layout, self._node_fold_state)
  end

  local renderer = Renderer:new(self.layout, self.buf):render()
  self.node_index = renderer:node_index()
  self.item_index = renderer:item_index()

  self.buf:win_call(function()
    -- Store the cursor and top line positions to be restored later
    local cursor_line = self.buf:cursor_line()
    local scrolloff = vim.api.nvim_get_option_value("scrolloff", { win = 0 })
    local top_line = vim.fn.line("w0")

    -- We must traverse `scrolloff` lines from `top_line`, skipping over any closed folds
    local top_line_nofold = top_line
    for _ = 1, scrolloff do
      top_line_nofold = top_line_nofold + 1
      -- If the line is within a closed fold, skip to the end of the fold
      if vim.fn.foldclosed(top_line_nofold) ~= -1 then
        top_line_nofold = vim.fn.foldclosedend(top_line_nofold)
      end
    end

    self.buf:unlock()
    self.buf:clear()
    self.buf:clear_namespace("default")
    self.buf:clear_namespace("ViewContext")
    self.buf:resize(#renderer.buffer.line)
    self.buf:set_lines(0, -1, false, renderer.buffer.line)
    self.buf:set_highlights(renderer.buffer.highlight)
    self.buf:set_extmarks(renderer.buffer.extmark)
    self.buf:set_line_highlights(renderer.buffer.line_highlight)
    self.buf:set_folds(renderer.buffer.fold)

    self.statuscolumn = {}
    self.statuscolumn.foldmarkers = {}

    for i = 1, #renderer.buffer.line do
      self.statuscolumn.foldmarkers[i] = false
    end

    for _, fold in ipairs(renderer.buffer.fold) do
      self.statuscolumn.foldmarkers[fold[1]] = fold[4]
    end

    -- Run on_open callbacks for hunks once buffer is rendered
    if self._node_fold_state then
      self:_update_on_open(self.layout, self._node_fold_state)
      self._node_fold_state = nil
    end

    self.buf:lock()

    -- First restore the top line, then restore the cursor after
    -- Only move the viewport if there are fewer lines available on the screen than are in the buffer
    if vim.fn.line("$") > vim.fn.line("w$") then
      self.buf:move_top_line(math.min(top_line_nofold, #renderer.buffer.line))
    end

    self.buf:move_cursor(math.min(cursor_line, #renderer.buffer.line))
  end)
end

Ui.col = Component.new(function(children, options)
  return {
    tag = "col",
    children = filter_layout(children),
    options = options,
  }
end)

Ui.row = Component.new(function(children, options)
  return {
    tag = "row",
    children = filter_layout(children),
    options = options,
  }
end)

Ui.text = Component.new(function(value, options, ...)
  if ... then
    error("Too many arguments")
  end

  vim.validate {
    options = { options, "table", true },
  }

  return {
    tag = "text",
    value = value or "",
    options = type(options) == "table" and options or nil,
    __index = {
      render = function(self)
        return self.value
      end,
    },
  }
end)

Ui.Component = Component

return Ui
