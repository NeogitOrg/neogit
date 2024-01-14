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
  local color = vim.api.nvim_get_hl(0, { name = name })
  if color["link"] then
    return get_fg(color["link"])
  elseif color["reverse"] and color["bg"] then
    return "#" .. to_hex(color["bg"])
  elseif color["fg"] then
    return "#" .. to_hex(color["fg"])
  end
end

---@param name string Syntax group name.
local function get_bg(name)
  local color = vim.api.nvim_get_hl(0, { name = name })
  if color["link"] then
    return get_bg(color["link"])
  elseif color["reverse"] and color["fg"] then
    return "#" .. to_hex(color["fg"])
  elseif color["bg"] then
    return "#" .. to_hex(color["bg"])
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

  local config = require("neogit.config")

  local bg_factor = vim.o.bg == "dark" and 1 or -1

  return {
    bg0        = bg:to_css(),
    bg1        = bg:shade(bg_factor * 0.019):to_css(),
    bg2        = bg:shade(bg_factor * 0.065):to_css(),
    bg3        = bg:shade(bg_factor * 0.11):to_css(),
    grey       = bg:shade(bg_factor * 0.4):to_css(),
    red        = red:to_css(),
    bg_red     = red:shade(bg_factor * -0.18):to_css(),
    line_red   = get_bg("DiffDelete") or red:shade(bg_factor * -0.6):set_saturation(0.4):to_css(),
    orange     = orange:to_css(),
    bg_orange  = orange:shade(bg_factor * -0.17):to_css(),
    yellow     = yellow:to_css(),
    bg_yellow  = yellow:shade(bg_factor * -0.17):to_css(),
    green      = green:to_css(),
    bg_green   = green:shade(bg_factor * -0.18):to_css(),
    line_green = get_bg("DiffAdd") or green:shade(bg_factor * -0.72):set_saturation(0.2):to_css(),
    cyan       = cyan:to_css(),
    bg_cyan    = cyan:shade(bg_factor * -0.18):to_css(),
    blue       = blue:to_css(),
    bg_blue    = blue:shade(bg_factor * -0.18):to_css(),
    purple     = purple:to_css(),
    bg_purple  = purple:shade(bg_factor * -0.18):to_css(),
    md_purple  = purple:shade(0.18):to_css(),
    italic     = config.values.highlight.italic,
    bold       = config.values.highlight.bold,
    underline  = config.values.highlight.underline
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
    NeogitGraphAuthor = { fg = palette.orange },
    NeogitGraphRed = { fg = palette.red },
    NeogitGraphWhite = { fg = palette.white },
    NeogitGraphYellow = { fg = palette.yellow },
    NeogitGraphGreen = { fg = palette.green },
    NeogitGraphCyan = { fg = palette.cyan },
    NeogitGraphBlue = { fg = palette.blue },
    NeogitGraphPurple = { fg = palette.purple },
    NeogitGraphGray = { fg = palette.grey },
    NeogitGraphOrange = { fg = palette.orange },
    NeogitGraphBoldRed = { fg = palette.red, bold = palette.bold },
    NeogitGraphBoldWhite = { fg = palette.white, bold = palette.bold },
    NeogitGraphBoldYellow = { fg = palette.yellow, bold = palette.bold },
    NeogitGraphBoldGreen = { fg = palette.green, bold = palette.bold },
    NeogitGraphBoldCyan = { fg = palette.cyan, bold = palette.bold },
    NeogitGraphBoldBlue = { fg = palette.blue, bold = palette.bold },
    NeogitGraphBoldPurple = { fg = palette.purple, bold = palette.bold },
    NeogitGraphBoldGray = { fg = palette.grey, bold = palette.bold },
    NeogitSignatureGood = { link = "NeogitGraphGreen" },
    NeogitSignatureBad = { link = "NeogitGraphBoldRed" },
    NeogitSignatureMissing = { link = "NeogitGraphPurple" },
    NeogitSignatureNone = { link = "Comment" },
    NeogitSignatureGoodUnknown = { link = "NeogitGraphBlue" },
    NeogitSignatureGoodExpired = { link = "NeogitGraphOrange" },
    NeogitSignatureGoodExpiredKey = { link = "NeogitGraphYellow" },
    NeogitSignatureGoodRevokedKey = { link = "NeogitGraphRed" },
    NeogitHunkHeader = { fg = palette.bg0, bg = palette.grey, bold = palette.bold },
    NeogitHunkHeaderHighlight = { fg = palette.bg0, bg = palette.md_purple, bold = palette.bold },
    NeogitDiffContext = { bg = palette.bg1 },
    NeogitDiffContextHighlight = { bg = palette.bg2 },
    NeogitDiffAdd = { bg = palette.line_green, fg = palette.bg_green },
    NeogitDiffAddHighlight = { bg = palette.line_green, fg = palette.green },
    NeogitDiffDelete = { bg = palette.line_red, fg = palette.bg_red },
    NeogitDiffDeleteHighlight = { bg = palette.line_red, fg = palette.red },
    NeogitPopupSectionTitle = { link = "Function" },
    NeogitPopupBranchName = { link = "String" },
    NeogitPopupBold = { bold = palette.bold },
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
    NeogitFilePath = { fg = palette.blue, italic = palette.italic },
    NeogitCommitViewHeader = { bg = palette.bg_cyan, fg = palette.bg0 },
    NeogitCommitViewDescription = { link = "String" },
    NeogitDiffHeader = { bg = palette.bg3, fg = palette.blue, bold = palette.bold },
    NeogitDiffHeaderHighlight = { bg = palette.bg3, fg = palette.orange, bold = palette.bold },
    NeogitCommandText = { link = "Comment" },
    NeogitCommandTime = { link = "Comment" },
    NeogitCommandCodeNormal = { link = "String" },
    NeogitCommandCodeError = { link = "Error" },
    NeogitBranch = { fg = palette.blue, bold = palette.bold },
    NeogitBranchHead = { fg = palette.blue, bold = palette.bold, underline = palette.underline },
    NeogitRemote = { fg = palette.green, bold = palette.bold },
    NeogitUnmergedInto = { fg = palette.bg_purple, bold = palette.bold },
    NeogitUnpushedTo = { fg = palette.bg_purple, bold = palette.bold },
    NeogitUnpulledFrom = { fg = palette.bg_purple, bold = palette.bold },
    NeogitObjectId = { link = "Comment" },
    NeogitStash = { link = "Comment" },
    NeogitRebaseDone = { link = "Comment" },
    NeogitCursorLine = { bg = palette.bg1 },
    NeogitFold = { fg = "None", bg = "None" },
    NeogitChangeModified = { fg = palette.bg_blue, bold = palette.bold, italic = palette.italic },
    NeogitChangeAdded = { fg = palette.bg_green, bold = palette.bold, italic = palette.italic },
    NeogitChangeDeleted = { fg = palette.bg_red, bold = palette.bold, italic = palette.italic },
    NeogitChangeRenamed = { fg = palette.bg_purple, bold = palette.bold, italic = palette.italic },
    NeogitChangeUpdated = { fg = palette.bg_orange, bold = palette.bold, italic = palette.italic },
    NeogitChangeCopied = { fg = palette.bg_cyan, bold = palette.bold, italic = palette.italic },
    NeogitChangeBothModified = { fg = palette.bg_yellow, bold = palette.bold, italic = palette.italic },
    NeogitChangeNewFile = { fg = palette.bg_green, bold = palette.bold, italic = palette.italic },
    NeogitSectionHeader = { fg = palette.bg_purple, bold = palette.bold },
    NeogitUntrackedfiles = { link = "NeogitSectionHeader" },
    NeogitUnstagedchanges = { link = "NeogitSectionHeader" },
    NeogitUnmergedchanges = { link = "NeogitSectionHeader" },
    NeogitUnpulledchanges = { link = "NeogitSectionHeader" },
    NeogitRecentcommits = { link = "NeogitSectionHeader" },
    NeogitStagedchanges = { link = "NeogitSectionHeader" },
    NeogitStashes = { link = "NeogitSectionHeader" },
    NeogitRebasing = { link = "NeogitSectionHeader" },
    NeogitPicking = { link = "NeogitSectionHeader" },
    NeogitReverting = { link = "NeogitSectionHeader" },
    NeogitTagName = { fg = palette.yellow },
    NeogitTagDistance = { fg = palette.cyan }
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
