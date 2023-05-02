local Ui = require("neogit.lib.ui")
local Component = require("neogit.lib.ui.component")
local util = require("neogit.lib.util")

local col = Ui.col
local row = Ui.row
local text = Ui.text

local map = util.map

local M = {}

local function highlight_ref_name(name)
  return name:match("/") and "String" or "Macro"
end

local function render_line_left(commit, args)
  return row {
    text(commit.oid:sub(1, 7), { highlight = "Comment" }),
    text(" "),
    text(args.graph and commit.graph or "", { highlight = "Include" }),
    text(" "),
  }
end

local function render_line_right(commit)
  if commit.rel_date:match("^%d ") then
    commit.rel_date = " " .. commit.rel_date
  end

  return row {
    text(
      util.str_truncate(commit.author_name, 19, ""), -- TODO: Add a max-width to render
      { highlight = "Constant", align_right = 20, padding_left = 1 }
    ),
    text(commit.rel_date, { highlight = "Special", align_right = 10 })
  }
end

local function render_line_center(commit, max_width)
  local content = {}

  if commit.ref_name ~= "" then
    local ref_name, _ = commit.ref_name:gsub("HEAD %-> ", "")
    local remote_name, local_name = unpack(vim.split(ref_name, ", "))

    if local_name then
      table.insert(content, text(local_name, { highlight = highlight_ref_name(local_name) }))
      table.insert(content, text(" "))

      max_width = max_width - #local_name - 1
    end

    if remote_name then
      table.insert(content, text(remote_name, { highlight = highlight_ref_name(remote_name) }))
      table.insert(content, text(" "))

      max_width = max_width - #remote_name - 1
    end
  end


  table.insert(
    content,
    text(
      util.str_truncate(commit.description[1], max_width),
      { align_right = max_width }
    )
  )

  return row(content)
end

M.Commit = Component.new(function(commit, args)
  local left_content   = render_line_left(commit, args)
  local right_content  = render_line_right(commit)
  local center_content = render_line_center(
    commit,
    vim.fn.winwidth(0) - 8 - left_content:get_width() - right_content:get_width()
  )

  return col(
    {
      row { left_content, center_content, right_content },
      col.hidden(true).padding_left(8) {
        row {
          text(args.graph and commit.graph or "", { highlight = "Include" }),
          text(" "),
          text("Author:     "),
          text(commit.author_name),
          text(" <"),
          text(commit.author_email),
          text(">"),
        },
        row {
          text(args.graph and commit.graph or "", { highlight = "Include" }),
          text(" "),
          text("AuthorDate: "),
          text(commit.author_date),
        },
        row {
          text(args.graph and commit.graph or "", { highlight = "Include" }),
          text(" "),
          text("Commit:     "),
          text(commit.committer_name),
          text(" <"),
          text(commit.committer_email),
          text(">"),
        },
        row {
          text(args.graph and commit.graph or "", { highlight = "Include" }),
          text(" "),
          text("CommitDate: "),
          text(commit.committer_date),
        },
        row {
          text(args.graph and commit.graph or "", { highlight = "Include" }),
        },
        col(map(
          commit.description,
          function(line)
            return row {
              text(args.graph and commit.graph or "", { highlight = "Include" }),
              text(" "),
              text(line)
            }
          end
        ), { highlight = "String" }),
      },
    },
    { oid = commit.oid }
  )
end)

M.Graph = Component.new(function(commit)
  return col.padding_left(8) {
    row { text(commit.graph, { highlight = "Include" }) }
  }
end)

---@param commits CommitLogEntry[]
---@param internal_args table
---@return table
function M.View(commits, internal_args)
  return util.filter_map(commits, function(commit)
    if commit.oid then
      return M.Commit(commit, internal_args)
    elseif internal_args.graph then
      return M.Graph(commit)
    end
  end)
end

return M
