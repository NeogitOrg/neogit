--#region TYPES

---@class HiSpec
---@field fg string
---@field bg string
---@field gui string
---@field sp string
---@field blend integer
---@field default boolean

---@class HiLinkSpec
---@field force boolean
---@field default boolean

--#endregion

local Color = require("neogit.lib.color").Color
local hl_store
local M = {}

---@param group string Syntax group name.
---@param opt HiSpec
function M.hi(group, opt)
  vim.cmd(
    string.format(
      "hi %s %s guifg=%s guibg=%s gui=%s guisp=%s blend=%s",
      opt.default and "default" or "",
      group,
      opt.fg or "NONE",
      opt.bg or "NONE",
      opt.gui or "NONE",
      opt.sp or "NONE",
      opt.blend or "NONE"
    )
  )
end

---@param name string Syntax group name.
---@return table|nil
function M.make_hl_link_attrs(name)
  local fg = M.get_fg(name, true)
  local bg = M.get_bg(name, true)
  local gui = M.get_gui(name, true)

  if fg or bg or gui then
    return { fg = fg, bg = bg, gui = gui }
  else
    return
  end
end

---@param name string Syntax group name.
---@param attr string Attribute name.
---@param trans boolean Translate the syntax group (follows links).
function M.get_hl_attr(name, attr, trans)
  local id = vim.fn.hlID(name)
  if id == 0 then
    return
  end
  if id and trans then
    id = vim.fn.synIDtrans(id)
  end
  if not id then
    return
  end

  local value = vim.fn.synIDattr(id, attr)
  if not value or value == "" then
    return
  end

  return value
end

---@param group_name string Syntax group name.
---@param trans boolean|nil Translate the syntax group (follows links). True by default.
function M.get_fg(group_name, trans)
  if type(trans) ~= "boolean" then
    trans = true
  end
  return M.get_hl_attr(group_name, "fg", trans)
end

---@param group_name string Syntax group name.
---@param trans boolean|nil Translate the syntax group (follows links). True by default.
function M.get_bg(group_name, trans)
  if type(trans) ~= "boolean" then
    trans = true
  end
  return M.get_hl_attr(group_name, "bg", trans)
end

---@param group_name string Syntax group name.
---@param trans boolean|nil Translate the syntax group (follows links). True by default.
function M.get_gui(group_name, trans)
  if type(trans) ~= "boolean" then
    trans = true
  end
  local hls = {}
  local attributes = {
    "bold",
    "italic",
    "reverse",
    "standout",
    "underline",
    "undercurl",
    "strikethrough",
  }

  for _, attr in ipairs(attributes) do
    if M.get_hl_attr(group_name, attr, trans) == "1" then
      table.insert(hls, attr)
    end
  end

  if #hls > 0 then
    return table.concat(hls, ",")
  end
end

local did_setup = false

function M.make_palette()
  local bg = vim.o.bg
  local hl_bg_normal = M.get_bg("Normal") or (bg == "dark" and "#22252A" or "#eeeeee")
  local bg_normal = Color.from_hex(hl_bg_normal)

  return {
    bg0 = M.get_bg("Normal"),
    bg1 = bg_normal:shade(0.019):to_css(),
    bg2 = bg_normal:shade(0.065):to_css(),
    bg3 = bg_normal:shade(0.11):to_css(),

    grey = bg_normal:shade(0.4):to_css(),

    red = M.get_fg("Error"),
    bg_red = Color.from_hex(M.get_fg("Error")):shade(-0.18):to_css(),
    line_red = M.get_bg("DiffDelete") or Color.from_hex(M.get_fg("Error"))
      :shade(-0.6)
      :set_saturation(0.4)
      :to_css(),

    orange = M.get_fg("SpecialChar"),
    bg_orange = Color.from_hex(M.get_fg("SpecialChar")):shade(-0.17):to_css(),

    yellow = M.get_fg("PreProc"),
    bg_yellow = Color.from_hex(M.get_fg("PreProc")):shade(-0.17):to_css(),

    green = M.get_fg("String"),
    bg_green = Color.from_hex(M.get_fg("String")):shade(-0.18):to_css(),
    line_green = M.get_bg("DiffAdd") or Color.from_hex(M.get_fg("String"))
      :shade(-0.72)
      :set_saturation(0.2)
      :to_css(),

    cyan = M.get_fg("Operator"),
    bg_cyan = Color.from_hex(M.get_fg("Operator")):shade(-0.18):to_css(),

    blue = M.get_fg("Macro"),
    bg_blue = Color.from_hex(M.get_fg("Macro")):shade(-0.18):to_css(),

    purple = M.get_fg("Include"),
    bg_purple = Color.from_hex(M.get_fg("Include")):shade(-0.18):to_css(),
    md_purple = "#c3a7e5",
  }
end

function M.setup()
  if did_setup then
    return
  end
  did_setup = true

  local palette = M.make_palette()

  hl_store = {
    NeogitHunkHeader = {
      fg = palette.bg0,
      bg = palette.grey,
      gui = "bold",
    },
    NeogitHunkHeaderHighlight = {
      fg = palette.bg0,
      bg = palette.md_purple,
      gui = "bold",
    },
    NeogitDiffContext = {
      bg = palette.bg1,
    },
    NeogitDiffContextHighlight = {
      bg = palette.bg2,
    },
    NeogitDiffAdd = {
      bg = palette.line_green,
      fg = palette.bg_green,
    },
    NeogitDiffAddHighlight = {
      bg = palette.line_green,
      fg = palette.green,
    },
    NeogitDiffDelete = {
      bg = palette.line_red,
      fg = palette.bg_red,
    },
    NeogitDiffDeleteHighlight = {
      bg = palette.line_red,
      fg = palette.red,
    },
    NeogitPopupSectionTitle = {
      link = "Function",
    },
    NeogitPopupBranchName = {
      link = "String",
    },
    NeogitPopupSwitchKey = {
      fg = palette.purple,
    },
    NeogitPopupSwitchEnabled = {
      link = "SpecialChar",
    },
    NeogitPopupSwitchDisabled = {
      link = "Comment",
    },
    NeogitPopupOptionKey = {
      fg = palette.purple,
    },
    NeogitPopupOptionEnabled = {
      link = "SpecialChar",
    },
    NeogitPopupOptionDisabled = {
      link = "Comment",
    },
    NeogitPopupConfigKey = {
      fg = palette.purple,
    },
    NeogitPopupConfigEnabled = {
      link = "SpecialChar",
    },
    NeogitPopupConfigDisabled = {
      link = "Comment",
    },
    NeogitPopupActionKey = {
      fg = palette.purple,
    },
    NeogitPopupActionDisabled = {
      link = "Comment",
    },
    NeogitFilePath = {
      fg = palette.blue,
      gui = "italic",
    },
    NeogitCommitViewHeader = {
      bg = palette.bg_cyan,
      fg = palette.bg0,
    },
    NeogitDiffHeader = {
      bg = palette.bg3,
      fg = palette.blue,
      gui = "bold",
    },
    NeogitDiffHeaderHighlight = {
      bg = palette.bg3,
      fg = palette.orange,
      gui = "bold",
    },
    NeogitNotificationInfo = {
      link = "DiagnosticInfo",
    },
    NeogitNotificationWarning = {
      link = "DiagnosticWarn",
    },
    NeogitNotificationError = {
      link = "DiagnosticError",
    },
    NeogitCommandText = {
      link = "Comment",
    },
    NeogitCommandTime = {
      link = "Comment",
    },
    NeogitCommandCodeNormal = {
      link = "String",
    },
    NeogitCommandCodeError = {
      link = "Error",
    },
    NeogitBranch = {
      fg = palette.orange,
      gui = "bold",
    },
    NeogitRemote = {
      fg = palette.green,
      gui = "bold",
    },
    NeogitUnmergedInto = {
      link = "Function",
    },
    NeogitUnpulledFrom = {
      link = "Function",
    },
    NeogitObjectId = {
      link = "Comment",
    },
    NeogitStash = {
      link = "Comment",
    },
    NeogitRebaseDone = {
      link = "Comment",
    },
    NeogitCursorLine = {
      bg = palette.bg1,
    },
    NeogitFold = {
      fg = "None",
      bg = "None",
    },
    NeogitChangeModified = {
      fg = palette.bg_blue,
      gui = "italic,bold",
    },
    NeogitChangeAdded = {
      fg = palette.bg_green,
      gui = "italic,bold",
    },
    NeogitChangeDeleted = {
      fg = palette.bg_red,
      gui = "italic,bold",
    },
    NeogitChangeRenamed = {
      fg = palette.bg_purple,
      gui = "italic,bold",
    },
    NeogitChangeUpdated = {
      fg = palette.bg_orange,
      gui = "italic,bold",
    },
    NeogitChangeCopied = {
      fg = palette.bg_cyan,
      gui = "italic,bold",
    },
    NeogitChangeBothModified = {
      fg = palette.bg_yellow,
      gui = "italic,bold",
    },
    NeogitChangeNewFile = {
      fg = palette.bg_green,
      gui = "italic,bold",
    },
    NeogitUntrackedfiles = {
      fg = palette.bg_purple,
      gui = "bold",
    },
    NeogitUnstagedchanges = {
      fg = palette.bg_purple,
      gui = "bold",
    },
    NeogitUnmergedchanges = {
      fg = palette.bg_purple,
      gui = "bold",
    },
    NeogitUnpulledchanges = {
      fg = palette.bg_purple,
      gui = "bold",
    },
    NeogitRecentcommits = {
      fg = palette.bg_purple,
      gui = "bold",
    },
    NeogitStagedchanges = {
      fg = palette.bg_purple,
      gui = "bold",
    },
    NeogitStashes = {
      fg = palette.bg_purple,
      gui = "bold",
    },
    NeogitRebasing = {
      fg = palette.bg_purple,
      gui = "bold",
    },
  }

  for group, hl in pairs(hl_store) do
    if vim.fn.hlID(group) == 0 then
      if hl.link then
        local attrs = M.make_hl_link_attrs(hl.link) or {}
        attrs.default = true
        M.hi(group, vim.tbl_extend("keep", hl, attrs))
      else
        M.hi(group, hl)
      end
    end
  end
end

return M
