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

local function to_hex(dec)
  local hex = string.format("%x", dec)
  if #hex < 6 then
    return string.rep("0", 6 - #hex) .. hex
  else
    return hex
  end
end

---@param name string Syntax group name.
local function get_fg(name)
  local color = vim.api.nvim_get_hl(0, { name = name })["fg"]
  if color then
    return "#" .. to_hex(color)
  end
end

---@param name string Syntax group name.
local function get_bg(name)
  local color = vim.api.nvim_get_hl(0, { name = name })["bg"]
  if color then
    return "#" .. to_hex(color)
  end
end


-- stylua: ignore start
local function make_palette()
  local bg     = Color.from_hex(get_bg("Normal") or (vim.o.bg == "dark" and "#22252A" or "#eeeeee"))
  local red    = Color.from_hex(get_fg("Error") or "#E06C75")
  local orange = Color.from_hex(get_fg("SpecialChar") or "#ffcb6b")
  local yellow = Color.from_hex(get_fg("PreProc") or "#FFE082")
  local green  = Color.from_hex(get_fg("String") or "#C3E88D")
  local cyan   = Color.from_hex(get_fg("Operator") or "#89ddff")
  local blue   = Color.from_hex(get_fg("Macro") or "#82AAFF")
  local purple = Color.from_hex(get_fg("Include") or "#C792EA")

  return {
    bg0        = bg:to_css(),
    bg1        = bg:shade(0.019):to_css(),
    bg2        = bg:shade(0.065):to_css(),
    bg3        = bg:shade(0.11):to_css(),
    grey       = bg:shade(0.4):to_css(),
    red        = red:to_css(),
    bg_red     = red:shade(-0.18):to_css(),
    line_red   = get_bg("DiffDelete") or red:shade(-0.6):set_saturation(0.4):to_css(),
    orange     = orange:to_css(),
    bg_orange  = orange:shade(-0.17):to_css(),
    yellow     = yellow:to_css(),
    bg_yellow  = yellow:shade(-0.17):to_css(),
    green      = green:to_css(),
    bg_green   = green:shade(-0.18):to_css(),
    line_green = get_bg("DiffAdd") or green:shade(-0.72):set_saturation(0.2):to_css(),
    cyan       = cyan:to_css(),
    bg_cyan    = cyan:shade(-0.18):to_css(),
    blue       = blue:to_css(),
    bg_blue    = blue:shade(-0.18):to_css(),
    purple     = purple:to_css(),
    bg_purple  = purple:shade(-0.18):to_css(),
    md_purple  = purple:shade(0.18):to_css(),
  }
end
-- stylua: ignore end

-- https://github.com/lewis6991/gitsigns.nvim/blob/1e01b2958aebb79f1c33e7427a1bac131a678e0d/lua/gitsigns/highlight.lua#L250
--- @param hl_name string
--- @return boolean
local function is_set(hl_name)
  local exists, hl = pcall(vim.api.nvim_get_hl, 0, { name = hl_name })
  if not exists then
    return false
  end

  return not vim.tbl_isempty(hl)
end

function M.setup()
  local palette = make_palette()

  -- stylua: ignore start
  hl_store = {
    NeogitGraphRed = { fg = palette.red },
    NeogitGraphWhite = { fg = palette.white },
    NeogitGraphOrange = { fg = palette.orange },
    NeogitGraphYellow = { fg = palette.yellow },
    NeogitGraphGreen = { fg = palette.green },
    NeogitGraphCyan = { fg = palette.cyan },
    NeogitGraphBlue = { fg = palette.blue },
    NeogitGraphPurple = { fg = palette.purple },
    NeogitGraphGray = { fg = palette.grey },
    NeogitGraphBoldRed = { fg = palette.red, bold = true },
    NeogitGraphBoldWhite = { fg = palette.white, bold = true },
    NeogitGraphBoldOrange = { fg = palette.orange, bold = true },
    NeogitGraphBoldYellow = { fg = palette.yellow, bold = true },
    NeogitGraphBoldGreen = { fg = palette.green, bold = true },
    NeogitGraphBoldCyan = { fg = palette.cyan, bold = true },
    NeogitGraphBoldBlue = { fg = palette.blue, bold = true },
    NeogitGraphBoldPurple = { fg = palette.purple, bold = true },
    NeogitGraphBoldGray = { fg = palette.grey, bold = true },
    NeogitHunkHeader = { fg = palette.bg0, bg = palette.grey, bold = true },
    NeogitHunkHeaderHighlight = { fg = palette.bg0, bg = palette.md_purple, bold = true },
    NeogitDiffContext = { bg = palette.bg1 },
    NeogitDiffContextHighlight = { bg = palette.bg2 },
    NeogitDiffAdd = { bg = palette.line_green, fg = palette.bg_green },
    NeogitDiffAddHighlight = { bg = palette.line_green, fg = palette.green },
    NeogitDiffDelete = { bg = palette.line_red, fg = palette.bg_red },
    NeogitDiffDeleteHighlight = { bg = palette.line_red, fg = palette.red },
    NeogitPopupSectionTitle = { link = "Function" },
    NeogitPopupBranchName = { link = "String" },
    NeogitPopupBold = { bold = true },
    NeogitPopupSwitchKey = { fg = palette.purple },
    NeogitPopupSwitchEnabled = { link = "SpecialChar" },
    NeogitPopupSwitchDisabled = { link = "Comment" },
    NeogitPopupOptionKey = { fg = palette.purple },
    NeogitPopupOptionEnabled = { link = "SpecialChar" },
    NeogitPopupOptionDisabled = { link = "Comment" },
    NeogitPopupConfigKey = { fg = palette.purple },
    NeogitPopupConfigEnabled = { link = "SpecialChar" },
    NeogitPopupConfigDisabled = { link = "Comment" },
    NeogitPopupActionKey = { fg = palette.purple },
    NeogitPopupActionDisabled = { link = "Comment" },
    NeogitFilePath = { fg = palette.blue, italic = true },
    NeogitCommitViewHeader = { bg = palette.bg_cyan, fg = palette.bg0 },
    NeogitDiffHeader = { bg = palette.bg3, fg = palette.blue, bold = true },
    NeogitDiffHeaderHighlight = { bg = palette.bg3, fg = palette.orange, bold = true },
    NeogitNotificationInfo = { link = "DiagnosticInfo" },
    NeogitNotificationWarning = { link = "DiagnosticWarn" },
    NeogitNotificationError = { link = "DiagnosticError" },
    NeogitCommandText = { link = "Comment" },
    NeogitCommandTime = { link = "Comment" },
    NeogitCommandCodeNormal = { link = "String" },
    NeogitCommandCodeError = { link = "Error" },
    NeogitBranch = { fg = palette.orange, bold = true },
    NeogitRemote = { fg = palette.green, bold = true },
    NeogitUnmergedInto = { link = "Function" },
    NeogitUnpulledFrom = { link = "Function" },
    NeogitObjectId = { link = "Comment" },
    NeogitCommitAuthor = { fg = palette.cyan },
    NeogitCommitAuthorEmail = { fg = palette.green },
    NeogitStash = { link = "Comment" },
    NeogitRebaseDone = { link = "Comment" },
    NeogitCursorLine = { bg = palette.bg1 },
    NeogitFold = { fg = "None", bg = "None" },
    NeogitChangeModified = { fg = palette.bg_blue, bold = true, italic = true },
    NeogitChangeAdded = { fg = palette.bg_green, bold = true, italic = true },
    NeogitChangeDeleted = { fg = palette.bg_red, bold = true, italic = true },
    NeogitChangeRenamed = { fg = palette.bg_purple, bold = true, italic = true },
    NeogitChangeUpdated = { fg = palette.bg_orange, bold = true, italic = true },
    NeogitChangeCopied = { fg = palette.bg_cyan, bold = true, italic = true },
    NeogitChangeBothModified = { fg = palette.bg_yellow, bold = true, italic = true },
    NeogitChangeNewFile = { fg = palette.bg_green, bold = true, italic = true },
    NeogitUntrackedfiles = { fg = palette.bg_purple, bold = true },
    NeogitUnstagedchanges = { fg = palette.bg_purple, bold = true },
    NeogitUnmergedchanges = { fg = palette.bg_purple, bold = true },
    NeogitUnpulledchanges = { fg = palette.bg_purple, bold = true },
    NeogitRecentcommits = { fg = palette.bg_purple, bold = true },
    NeogitStagedchanges = { fg = palette.bg_purple, bold = true },
    NeogitStashes = { fg = palette.bg_purple, bold = true },
    NeogitRebasing = { fg = palette.bg_purple, bold = true },
  }
  -- stylua: ignore end

  for group, hl in pairs(hl_store) do
    if not is_set(group) then
      hl.default = true
      vim.api.nvim_set_hl(0, group, hl)
    end
  end
end

return M
