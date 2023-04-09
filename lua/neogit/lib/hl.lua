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
local api = vim.api
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

---@param from string Syntax group name.
---@param to string Syntax group name.
---@param opt HiLinkSpec
function M.hi_link(from, to, opt)
  vim.cmd(
    string.format(
      "hi%s %s link %s %s",
      opt.force and "!" or "",
      opt.default and "default" or "",
      from,
      to or ""
    )
  )
end

---@param name string Syntax group name.
---@param attr string Attribute name.
---@param trans boolean Translate the syntax group (follows links).
function M.get_hl_attr(name, attr, trans)
  local id = api.nvim_get_hl_id_by_name(name)
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
---@param trans boolean Translate the syntax group (follows links). True by default.
function M.get_fg(group_name, trans)
  if type(trans) ~= "boolean" then
    trans = true
  end
  return M.get_hl_attr(group_name, "fg", trans)
end

---@param group_name string Syntax group name.
---@param trans boolean Translate the syntax group (follows links). True by default.
function M.get_bg(group_name, trans)
  if type(trans) ~= "boolean" then
    trans = true
  end
  return M.get_hl_attr(group_name, "bg", trans)
end

---@param group_name string Syntax group name.
---@param trans boolean Translate the syntax group (follows links). True by default.
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

function M.setup()
  local bg = vim.o.bg
  local hl_fg_normal = M.get_fg("Normal") or (bg == "dark" and "#eeeeee" or "#111111")
  local hl_bg_normal = M.get_bg("Normal") or (bg == "dark" and "#111111" or "#eeeeee")

  -- Generate highlights by lightening for dark color schemes, and darkening
  -- for light color schemes.
  local bg_normal = Color.from_hex(hl_bg_normal)
  local sign = bg_normal.lightness >= 0.5 and -1 or 1

  local bg_hunk_header_hl = bg_normal:shade(0.15 * sign)
  local bg_diff_context = bg_normal:shade(0.09 * sign)
  local bg_diff_context_hl = bg_normal:shade(0.075 * sign)

  hl_store = {
    NeogitHunkHeader = {
      bg = bg_diff_context_hl:to_css()
    },
    NeogitHunkHeaderHighlight = {
      bg = bg_hunk_header_hl:to_css()
    },

    NeogitDiffContext = {
      bg = bg_diff_context:to_css()
    },
    NeogitDiffContextHighlight = {
      bg = bg_diff_context_hl:to_css()
    },

    NeogitDiffAdd             = { default = true, link = "DiffAdd" },
    NeogitDiffAddHighlight = {
      bg = M.get_bg("DiffAdd", false) or bg_diff_context_hl:to_css(),
      fg = M.get_fg("DiffAdd", false) or M.get_fg("diffAdded") or hl_fg_normal,
      gui = M.get_gui("DiffAdd", false),
    },

    NeogitDiffDelete          = { default = true, link = "DiffDelete" },
    NeogitDiffDeleteHighlight = {
      bg = M.get_bg("DiffDelete", false) or bg_diff_context_hl:to_css(),
      fg = M.get_fg("DiffDelete", false) or M.get_fg("diffRemoved") or hl_fg_normal,
      gui = M.get_gui("DiffDelete", false),
    },

    NeogitPopupSectionTitle   = { default = true, link = "Function" },
    NeogitPopupBranchName     = { default = true, link = "String" },
    NeogitPopupSwitchKey      = { default = true, link = "Operator" },
    NeogitPopupSwitchEnabled  = { default = true, link = "SpecialChar" },
    NeogitPopupSwitchDisabled = { default = true, link = "Comment" },
    NeogitPopupOptionKey      = { default = true, link = "Operator" },
    NeogitPopupOptionEnabled  = { default = true, link = "SpecialChar" },
    NeogitPopupOptionDisabled = { default = true, link = "Comment" },
    NeogitPopupConfigKey      = { default = true, link = "Operator" },
    NeogitPopupConfigEnabled  = { default = true, link = "SpecialChar" },
    NeogitPopupConfigDisabled = { default = true, link = "Comment" },
    NeogitPopupActionDisabled = { default = true, link = "Comment" },
    NeogitPopupActionKey      = { default = true, link = "Operator" },


    NeogitFilePath            = { fg = "#798bf2" },
    NeogitCommitViewHeader    = { fg = "#0b0d0d", bg = "#94bbd1" },
    NeogitDiffHeader          = { gui = "bold" },

    NeogitNotificationInfo    = { default = true, link = "DiagnosticInfo" },
    NeogitNotificationWarning = { default = true, link = "DiagnosticWarn" },
    NeogitNotificationError   = { default = true, link = "DiagnosticError" },

    NeogitCommandText         = { default = true, link = "Comment" },
    NeogitCommandTime         = { default = true, link = "Comment" },
    NeogitCommandCodeNormal   = { default = true, link = "String" },
    NeogitCommandCodeError    = { default = true, link = "Error" },

    NeogitBranch              = { default = true, link = "Macro" },
    NeogitRemote              = { default = true, link = "SpecialChar" },
    NeogitObjectId            = { default = true, link = "Comment" },
    NeogitUnmergedInto        = { default = true, link = "Function" },
    NeogitUnpulledFrom        = { default = true, link = "Function" },
    NeogitStash               = { default = true, link = "Comment" },
    NeogitRebaseDone          = { default = true, link = "Comment" },
    NeogitCursorLine          = { default = true, link = "CursorLine" },

    NeogitFold                = { fg = "None", bg = "None", },

    NeogitNormal              = {},
    NeogitNotification        = {},
    NeogitDiffHeaderHighlight = {},
    NeogitCommitMessage       = {},

    NeogitChangeModified      = {},
    NeogitChangeAdded         = {},
    NeogitChangeDeleted       = {},
    NeogitChangeRenamed       = {},
    NeogitChangeUpdated       = {},
    NeogitChangeCopied        = {},
    NeogitChangeBothModified  = {},
    NeogitChangeNewFile       = {},

    NeogitUntrackedfiles      = { default = true, link = "Function" },
    NeogitUnstagedchanges     = { default = true, link = "Function" },
    NeogitUnmergedchanges     = { default = true, link = "Function" },
    NeogitUnpulledchanges     = { default = true, link = "Function" },
    NeogitRecentcommits       = { default = true, link = "Function" },
    NeogitStagedchanges       = { default = true, link = "Function" },
    NeogitStashes             = { default = true, link = "Function" },
    NeogitRebasing            = { default = true, link = "Function" },
  }

  for group, hl in pairs(hl_store) do
    if vim.fn.hlID(group) == 0 then
      if hl.link then
        M.hi_link(group, hl.link, hl)
      else
        M.hi(group, hl)
      end
    end
  end
end

return M
