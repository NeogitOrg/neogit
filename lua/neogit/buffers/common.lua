local Ui = require("neogit.lib.ui")
local Component = require("neogit.lib.ui.component")
local util = require("neogit.lib.util")
local git = require("neogit.lib.git")

local text = Ui.text
local col = Ui.col
local row = Ui.row
local map = util.map
local flat_map = util.flat_map
local filter = util.filter
local intersperse = util.intersperse
local range = util.range

local M = {}

local diff_add_start = "+"
local diff_delete_start = "-"

M.Diff = Component.new(function(diff)
  local hunk_props = map(diff.hunks, function(hunk)
    local header = diff.lines[hunk.diff_from]

    local content = map(range(hunk.diff_from + 1, hunk.diff_to), function(i)
      return diff.lines[i]
    end)

    return {
      header = header,
      content = content,
    }
  end)

  return col.tag("Diff") {
    text(string.format("%s %s", diff.kind, diff.file), { sign = "NeogitDiffHeader" }),
    col.tag("DiffContent") {
      col.tag("DiffInfo")(map(diff.info, text)),
      col.tag("HunkList")(map(hunk_props, M.Hunk)),
    },
  }
end)

local HunkLine = Component.new(function(line)
  local sign

  if string.sub(line, 1, 1) == diff_add_start then
    sign = "NeogitDiffAdd"
  elseif string.sub(line, 1, 1) == diff_delete_start then
    sign = "NeogitDiffDelete"
  else
    sign = "NeogitDiffContext"
  end

  return text(line, { sign = sign })
end)

M.Hunk = Component.new(function(props)
  return col.tag("Hunk") {
    text.sign("NeogitHunkHeader")(props.header),
    col.tag("HunkContent")(map(props.content, HunkLine)),
  }
end)

M.List = Component.new(function(props)
  local children = filter(props.items, function(x)
    return type(x) == "table"
  end)

  if props.separator then
    children = intersperse(children, text(props.separator))
  end

  local container = col

  if props.horizontal then
    container = row
  end

  return container.tag("List")(children)
end)

local function build_graph(graph)
  if type(graph) == "table" then
    return util.map(graph, function(g)
      return text(g.text, { highlight = string.format("NeogitGraph%s", g.color) })
    end)
  else
    return { text(graph, { highlight = "Include" }) }
  end
end

-- - '%G?': show "G" for a good (valid) signature,
--   "B" for a bad signature,
--   "U" for a good signature with unknown validity,
--   "X" for a good signature that has expired,
--   "Y" for a good signature made by an expired key,
--   "R" for a good signature made by a revoked key,
--   "E" if the signature cannot be checked (e.g. missing key)
--   and "N" for no signature
local highlight_for_signature = {
  G = "NeogitSignatureGood",
  B = "NeogitSignatureBad",
  U = "NeogitSignatureGoodUnknown",
  X = "NeogitSignatureGoodExpired",
  Y = "NeogitSignatureGoodExpiredKey",
  R = "NeogitSignatureGoodRevokedKey",
  E = "NeogitSignatureMissing",
  N = "NeogitSignatureNone",
}

M.CommitEntry = Component.new(function(commit, args)
  local ref = {}

  -- Parse out ref names
  if args.decorate and commit.ref_name ~= "" then
    local info = git.log.branch_info(commit.ref_name, git.remote.list())

    -- Render local only branches first
    for name, _ in pairs(info.locals) do
      if info.remotes[name] == nil then
        local branch_highlight = info.head == name and "NeogitBranchHead" or "NeogitBranch"
        table.insert(ref, text(name, { highlight = branch_highlight }))
        table.insert(ref, text(" "))
      end
    end

    -- Render tracked (local+remote) branches next
    for name, remotes in pairs(info.remotes) do
      if #remotes == 1 then
        table.insert(ref, text(remotes[1] .. "/", { highlight = "NeogitRemote" }))
      end
      if #remotes > 1 then
        table.insert(ref, text("{" .. table.concat(remotes, ",") .. "}/", { highlight = "NeogitRemote" }))
      end
      local branch_highlight = info.head == name and "NeogitBranchHead" or "NeogitBranch"
      local locally = info.locals[name] ~= nil
      table.insert(ref, text(name, { highlight = locally and branch_highlight or "NeogitRemote" }))
      table.insert(ref, text(" "))
    end
    for _, tag in pairs(info.tags) do
      table.insert(ref, text(tag, { highlight = "NeogitTagName" }))
      table.insert(ref, text(" "))
    end
  end

  if commit.rel_date:match(" years?,") then
    commit.rel_date, _ = commit.rel_date:gsub(" years?,", "y")
    commit.rel_date = commit.rel_date .. " "
  elseif commit.rel_date:match("^%d ") then
    commit.rel_date = " " .. commit.rel_date
  end

  local graph = args.graph and build_graph(commit.graph) or { text("") }

  local details
  if args.details then
    details = col.hidden(true).padding_left(8) {
      row(util.merge(graph, {
        text(" "),
        text("Author:     ", { highlight = "Comment" }),
        text(commit.author_name, { highlight = "NeogitGraphAuthor" }),
        text(" <"),
        text(commit.author_email),
        text(">"),
      })),
      row(util.merge(graph, {
        text(" "),
        text("AuthorDate: ", { highlight = "Comment" }),
        text(commit.author_date),
      })),
      row(util.merge(graph, {
        text(" "),
        text("Commit:     ", { highlight = "Comment" }),
        text(commit.committer_name),
        text(" <"),
        text(commit.committer_email),
        text(">"),
      })),
      row(util.merge(graph, {
        text(" "),
        text("CommitDate: ", { highlight = "Comment" }),
        text(commit.committer_date),
      })),
      row(graph),
      col(
        flat_map({ commit.subject, commit.body }, function(line)
          local lines = vim.split(line, "\\n")

          -- TODO: More correctly handle newlines/wrapping in messages
          -- lines = util.flat_map(lines, function(line)
          --   return util.str_wrap(line, vim.o.columns * 0.6)
          -- end)

          lines = map(lines, function(l)
            return row(util.merge(graph, { text(" "), text(l) }))
          end)

          if #lines > 2 then
            return util.merge({ row(graph) }, lines, { row(graph) })
          elseif #lines > 1 then
            return util.merge({ row(graph) }, lines)
          else
            return lines
          end
        end),
        { highlight = "NeogitCommitViewDescription" }
      ),
    }
  end

  return col({
    row(
      util.merge({
        text(commit.oid:sub(1, 7), {
          highlight = commit.verification_flag and highlight_for_signature[commit.verification_flag]
            or "Comment",
        }),
        text(" "),
      }, graph, { text(" ") }, ref, { text(commit.subject) }),
      {
        virtual_text = {
          { " ", "Constant" },
          {
            util.str_clamp(commit.author_name, 30 - (#commit.rel_date > 10 and #commit.rel_date or 10)),
            "NeogitGraphAuthor",
          },
          { util.str_min_width(commit.rel_date, 10), "Special" },
        },
      }
    ),
    details,
  }, { oid = commit.oid })
end)

M.CommitGraph = Component.new(function(commit, _)
  return col.padding_left(8) { row(build_graph(commit.graph)) }
end)

M.Grid = Component.new(function(props)
  props = vim.tbl_extend("force", {
    -- Gap between columns
    gap = 0,
    columns = true, -- whether the items represents a list of columns instead of a list of row
    items = {},
  }, props)

  --- Transpose
  if props.columns then
    local new_items = {}
    local row_count = 0
    for i = 1, #props.items do
      local l = #props.items[i]

      if l > row_count then
        row_count = l
      end
    end
    for _ = 1, row_count do
      table.insert(new_items, {})
    end
    for i = 1, #props.items do
      for j = 1, row_count do
        local x = props.items[i][j] or text("")
        table.insert(new_items[j], x)
      end
    end
    props.items = new_items
  end

  local rendered = {}
  local column_widths = {}

  for i = 1, #props.items do
    local children = {}

    -- TODO: seems to be a leftover from when the grid was column major
    -- if i ~= 1 then
    --   children = map(range(props.gap), function()
    --     return text("")
    --   end)
    -- end

    -- current row
    local r = props.items[i]

    for j = 1, #r do
      local item = r[j]
      local c = props.render_item(item)

      if c.tag ~= "text" and c.tag ~= "row" then
        error("Grid component only supports text and row components for now")
      end

      local c_width = c:get_width()
      children[j] = c

      -- Compute the maximum element width of each column to pad all columns to the same vertical line
      if c_width > (column_widths[j] or 0) then
        column_widths[j] = c_width
      end
    end

    rendered[i] = row(children)
  end

  for i = 1, #rendered do
    -- current row
    local r = rendered[i]

    -- Draw each column of the current row
    for j = 1, #r.children do
      local item = r.children[j]
      local gap_str = ""
      local column_width = column_widths[j] or 0

      -- Intersperse each column item with a gap
      if j ~= 1 then
        gap_str = string.rep(" ", props.gap)
      end

      if item.tag == "text" then
        item.value = gap_str .. string.format("%" .. column_width .. "s", item.value)
      elseif item.tag == "row" then
        table.insert(item.children, 1, text(gap_str))
        local width = item:get_width()
        local remaining_width = column_width - width + props.gap
        table.insert(item.children, text(string.rep(" ", remaining_width)))
      else
        error("TODO")
      end
    end
  end

  return col(rendered)
end)

return M
