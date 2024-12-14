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

---@param dec number
---@return string
local function to_hex(dec)
  local hex = string.format("%x", dec)
  if #hex < 6 then
    return string.rep("0", 6 - #hex) .. hex
  else
    return hex
  end
end

---@param name string Syntax group name.
---@return string|nil
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
---@return string|nil
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

---@class NeogitColorPalette
---@field bg0        string  Darkest background color
---@field bg1        string  Second darkest background color
---@field bg2        string  Second lightest background color
---@field bg3        string  Lightest background color
---@field grey       string  middle grey shade for foreground
---@field white      string  Foreground white (main text)
---@field red        string  Foreground red
---@field bg_red     string  Background red
---@field line_red   string  Cursor line highlight for red regions, like deleted hunks
---@field orange     string  Foreground orange
---@field bg_orange  string  background orange
---@field yellow     string  Foreground yellow
---@field bg_yellow  string  background yellow
---@field green      string  Foreground green
---@field bg_green   string  Background green
---@field line_green string  Cursor line highlight for green regions, like added hunks
---@field cyan       string  Foreground cyan
---@field bg_cyan    string  Background cyan
---@field blue       string  Foreground blue
---@field bg_blue    string  Background blue
---@field purple     string  Foreground purple
---@field bg_purple  string  Background purple
---@field md_purple  string  Background _medium_ purple. Lighter than bg_purple.
---@field italic     boolean enable italics?
---@field bold       boolean enable bold?
---@field underline  boolean enable underline?

-- stylua: ignore start
---@param config NeogitConfig
---@return NeogitColorPalette
local function make_palette(config)
  local bg        = Color.from_hex(get_bg("Normal") or (vim.o.bg == "dark" and "#22252A" or "#eeeeee"))
  local fg        = Color.from_hex((vim.o.bg == "dark" and "#fcfcfc" or "#22252A"))
  local red       = Color.from_hex(config.highlight.red    or get_fg("Error")       or "#E06C75")
  local orange    = Color.from_hex(config.highlight.orange or get_fg("SpecialChar") or "#ffcb6b")
  local yellow    = Color.from_hex(config.highlight.yellow or get_fg("PreProc")     or "#FFE082")
  local green     = Color.from_hex(config.highlight.green  or get_fg("String")      or "#C3E88D")
  local cyan      = Color.from_hex(config.highlight.cyan   or get_fg("Operator")    or "#89ddff")
  local blue      = Color.from_hex(config.highlight.blue   or get_fg("Macro")       or "#82AAFF")
  local purple    = Color.from_hex(config.highlight.purple or get_fg("Include")     or "#C792EA")

  local bg_factor = vim.o.bg == "dark" and 1 or -1

  local default   = {
    bg0        = bg:to_css(),
    bg1        = bg:shade(bg_factor * 0.019):to_css(),
    bg2        = bg:shade(bg_factor * 0.065):to_css(),
    bg3        = bg:shade(bg_factor * 0.11):to_css(),
    grey       = bg:shade(bg_factor * 0.4):to_css(),
    white      = fg:to_css(),
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
    italic     = true,
    bold       = true,
    underline  = true,
  }

  return vim.tbl_extend("keep", config.highlight or {}, default)
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

---@param config NeogitConfig
function M.setup(config)
  local palette = make_palette(config)

  -- stylua: ignore
  hl_store = {
    NeogitGraphAuthor              = { fg = palette.orange },
    NeogitGraphRed                 = { fg = palette.red },
    NeogitGraphWhite               = { fg = palette.white },
    NeogitGraphYellow              = { fg = palette.yellow },
    NeogitGraphGreen               = { fg = palette.green },
    NeogitGraphCyan                = { fg = palette.cyan },
    NeogitGraphBlue                = { fg = palette.blue },
    NeogitGraphPurple              = { fg = palette.purple },
    NeogitGraphGray                = { fg = palette.grey },
    NeogitGraphOrange              = { fg = palette.orange },
    NeogitGraphBoldOrange          = { fg = palette.orange, bold = palette.bold },
    NeogitGraphBoldRed             = { fg = palette.red, bold = palette.bold },
    NeogitGraphBoldWhite           = { fg = palette.white, bold = palette.bold },
    NeogitGraphBoldYellow          = { fg = palette.yellow, bold = palette.bold },
    NeogitGraphBoldGreen           = { fg = palette.green, bold = palette.bold },
    NeogitGraphBoldCyan            = { fg = palette.cyan, bold = palette.bold },
    NeogitGraphBoldBlue            = { fg = palette.blue, bold = palette.bold },
    NeogitGraphBoldPurple          = { fg = palette.purple, bold = palette.bold },
    NeogitGraphBoldGray            = { fg = palette.grey, bold = palette.bold },
    NeogitSubtleText               = { link = "Comment" },
    NeogitSignatureGood            = { link = "NeogitGraphGreen" },
    NeogitSignatureBad             = { link = "NeogitGraphBoldRed" },
    NeogitSignatureMissing         = { link = "NeogitGraphPurple" },
    NeogitSignatureNone            = { link = "NeogitSubtleText" },
    NeogitSignatureGoodUnknown     = { link = "NeogitGraphBlue" },
    NeogitSignatureGoodExpired     = { link = "NeogitGraphOrange" },
    NeogitSignatureGoodExpiredKey  = { link = "NeogitGraphYellow" },
    NeogitSignatureGoodRevokedKey  = { link = "NeogitGraphRed" },
    NeogitCursorLine               = { link = "CursorLine" },
    NeogitHunkMergeHeader          = { fg = palette.bg2, bg = palette.grey, bold = palette.bold },
    NeogitHunkMergeHeaderHighlight = { fg = palette.bg0, bg = palette.bg_cyan, bold = palette.bold },
    NeogitHunkMergeHeaderCursor    = { fg = palette.bg0, bg = palette.bg_cyan, bold = palette.bold },
    NeogitHunkHeader               = { fg = palette.bg0, bg = palette.grey, bold = palette.bold },
    NeogitHunkHeaderHighlight      = { fg = palette.bg0, bg = palette.md_purple, bold = palette.bold },
    NeogitHunkHeaderCursor         = { fg = palette.bg0, bg = palette.md_purple, bold = palette.bold },
    NeogitDiffContext              = { bg = palette.bg1 },
    NeogitDiffContextHighlight     = { bg = palette.bg2 },
    NeogitDiffContextCursor        = { bg = palette.bg1 },
    NeogitDiffAdditions            = { fg = palette.bg_green },
    NeogitDiffAdd                  = { bg = palette.line_green, fg = palette.bg_green },
    NeogitDiffAddHighlight         = { bg = palette.line_green, fg = palette.green },
    NeogitDiffAddCursor            = { bg = palette.bg1, fg = palette.green },
    NeogitDiffDeletions            = { fg = palette.bg_red },
    NeogitDiffDelete               = { bg = palette.line_red, fg = palette.bg_red },
    NeogitDiffDeleteHighlight      = { bg = palette.line_red, fg = palette.red },
    NeogitDiffDeleteCursor         = { bg = palette.bg1, fg = palette.red },
    NeogitPopupSectionTitle        = { link = "Function" },
    NeogitPopupBranchName          = { link = "String" },
    NeogitPopupBold                = { bold = palette.bold },
    NeogitPopupSwitchKey           = { fg = palette.purple },
    NeogitPopupSwitchEnabled       = { link = "SpecialChar" },
    NeogitPopupSwitchDisabled      = { link = "NeogitSubtleText" },
    NeogitPopupOptionKey           = { fg = palette.purple },
    NeogitPopupOptionEnabled       = { link = "SpecialChar" },
    NeogitPopupOptionDisabled      = { link = "NeogitSubtleText" },
    NeogitPopupConfigKey           = { fg = palette.purple },
    NeogitPopupConfigEnabled       = { link = "SpecialChar" },
    NeogitPopupConfigDisabled      = { link = "NeogitSubtleText" },
    NeogitPopupActionKey           = { fg = palette.purple },
    NeogitPopupActionDisabled      = { link = "NeogitSubtleText" },
    NeogitFilePath                 = { fg = palette.blue, italic = palette.italic },
    NeogitCommitViewHeader         = { bg = palette.bg_cyan, fg = palette.bg0 },
    NeogitCommitViewDescription    = { link = "String" },
    NeogitDiffHeader               = { bg = palette.bg3, fg = palette.blue, bold = palette.bold },
    NeogitDiffHeaderHighlight      = { bg = palette.bg3, fg = palette.orange, bold = palette.bold },
    NeogitCommandText              = { link = "NeogitSubtleText" },
    NeogitCommandTime              = { link = "NeogitSubtleText" },
    NeogitCommandCodeNormal        = { link = "String" },
    NeogitCommandCodeError         = { link = "Error" },
    NeogitBranch                   = { fg = palette.blue, bold = palette.bold },
    NeogitBranchHead               = { fg = palette.blue, bold = palette.bold, underline = palette.underline },
    NeogitRemote                   = { fg = palette.green, bold = palette.bold },
    NeogitUnmergedInto             = { fg = palette.bg_purple, bold = palette.bold },
    NeogitUnpushedTo               = { fg = palette.bg_purple, bold = palette.bold },
    NeogitUnpulledFrom             = { fg = palette.bg_purple, bold = palette.bold },
    NeogitStatusHEAD               = {},
    NeogitObjectId                 = { link = "NeogitSubtleText" },
    NeogitStash                    = { link = "NeogitSubtleText" },
    NeogitRebaseDone               = { link = "NeogitSubtleText" },
    NeogitFold                     = { fg = "None", bg = "None" },
    NeogitWinSeparator             = { link = "WinSeparator" },
    NeogitChangeMuntracked         = { link = "NeogitChangeModified" },
    NeogitChangeAuntracked         = { link = "NeogitChangeAdded" },
    NeogitChangeNuntracked         = { link = "NeogitChangeNewFile" },
    NeogitChangeDuntracked         = { link = "NeogitChangeDeleted" },
    NeogitChangeCuntracked         = { link = "NeogitChangeCopied" },
    NeogitChangeUuntracked         = { link = "NeogitChangeUpdated" },
    NeogitChangeRuntracked         = { link = "NeogitChangeRenamed" },
    NeogitChangeDDuntracked        = { link = "NeogitChangeUnmerged" },
    NeogitChangeUUuntracked        = { link = "NeogitChangeUnmerged" },
    NeogitChangeAAuntracked        = { link = "NeogitChangeUnmerged" },
    NeogitChangeDUuntracked        = { link = "NeogitChangeUnmerged" },
    NeogitChangeUDuntracked        = { link = "NeogitChangeUnmerged" },
    NeogitChangeAUuntracked        = { link = "NeogitChangeUnmerged" },
    NeogitChangeUAuntracked        = { link = "NeogitChangeUnmerged" },
    NeogitChangeUntrackeduntracked = { fg = "None" },
    NeogitChangeMunstaged          = { link = "NeogitChangeModified" },
    NeogitChangeAunstaged          = { link = "NeogitChangeAdded" },
    NeogitChangeNunstaged          = { link = "NeogitChangeNewFile" },
    NeogitChangeDunstaged          = { link = "NeogitChangeDeleted" },
    NeogitChangeCunstaged          = { link = "NeogitChangeCopied" },
    NeogitChangeUunstaged          = { link = "NeogitChangeUpdated" },
    NeogitChangeRunstaged          = { link = "NeogitChangeRenamed" },
    NeogitChangeTunstaged          = { link = "NeogitChangeUpdated" },
    NeogitChangeDDunstaged         = { link = "NeogitChangeUnmerged" },
    NeogitChangeUUunstaged         = { link = "NeogitChangeUnmerged" },
    NeogitChangeAAunstaged         = { link = "NeogitChangeUnmerged" },
    NeogitChangeDUunstaged         = { link = "NeogitChangeUnmerged" },
    NeogitChangeUDunstaged         = { link = "NeogitChangeUnmerged" },
    NeogitChangeAUunstaged         = { link = "NeogitChangeUnmerged" },
    NeogitChangeUAunstaged         = { link = "NeogitChangeUnmerged" },
    NeogitChangeUntrackedunstaged  = { fg = "None" },
    NeogitChangeMstaged            = { link = "NeogitChangeModified" },
    NeogitChangeAstaged            = { link = "NeogitChangeAdded" },
    NeogitChangeNstaged            = { link = "NeogitChangeNewFile" },
    NeogitChangeDstaged            = { link = "NeogitChangeDeleted" },
    NeogitChangeCstaged            = { link = "NeogitChangeCopied" },
    NeogitChangeUstaged            = { link = "NeogitChangeUpdated" },
    NeogitChangeRstaged            = { link = "NeogitChangeRenamed" },
    NeogitChangeTstaged            = { link = "NeogitChangeUpdated" },
    NeogitChangeDDstaged           = { link = "NeogitChangeUnmerged" },
    NeogitChangeUUstaged           = { link = "NeogitChangeUnmerged" },
    NeogitChangeAAstaged           = { link = "NeogitChangeUnmerged" },
    NeogitChangeDUstaged           = { link = "NeogitChangeUnmerged" },
    NeogitChangeUDstaged           = { link = "NeogitChangeUnmerged" },
    NeogitChangeAUstaged           = { link = "NeogitChangeUnmerged" },
    NeogitChangeUAstaged           = { link = "NeogitChangeUnmerged" },
    NeogitChangeUntrackedstaged    = { fg = "None" },
    NeogitChangeModified           = { fg = palette.bg_blue, bold = palette.bold, italic = palette.italic },
    NeogitChangeAdded              = { fg = palette.bg_green, bold = palette.bold, italic = palette.italic },
    NeogitChangeDeleted            = { fg = palette.bg_red, bold = palette.bold, italic = palette.italic },
    NeogitChangeRenamed            = { fg = palette.bg_purple, bold = palette.bold, italic = palette.italic },
    NeogitChangeUpdated            = { fg = palette.bg_orange, bold = palette.bold, italic = palette.italic },
    NeogitChangeCopied             = { fg = palette.bg_cyan, bold = palette.bold, italic = palette.italic },
    NeogitChangeUnmerged           = { fg = palette.bg_yellow, bold = palette.bold, italic = palette.italic },
    NeogitChangeNewFile            = { fg = palette.bg_green, bold = palette.bold, italic = palette.italic },
    NeogitSectionHeader            = { fg = palette.bg_purple, bold = palette.bold },
    NeogitSectionHeaderCount       = {},
    NeogitUntrackedfiles           = { link = "NeogitSectionHeader" },
    NeogitUnstagedchanges          = { link = "NeogitSectionHeader" },
    NeogitUnmergedchanges          = { link = "NeogitSectionHeader" },
    NeogitUnpulledchanges          = { link = "NeogitSectionHeader" },
    NeogitUnpushedchanges          = { link = "NeogitSectionHeader" },
    NeogitRecentcommits            = { link = "NeogitSectionHeader" },
    NeogitStagedchanges            = { link = "NeogitSectionHeader" },
    NeogitStashes                  = { link = "NeogitSectionHeader" },
    NeogitMerging                  = { link = "NeogitSectionHeader" },
    NeogitBisecting                = { link = "NeogitSectionHeader" },
    NeogitRebasing                 = { link = "NeogitSectionHeader" },
    NeogitPicking                  = { link = "NeogitSectionHeader" },
    NeogitReverting                = { link = "NeogitSectionHeader" },
    NeogitTagName                  = { fg = palette.yellow },
    NeogitTagDistance              = { fg = palette.cyan },
    NeogitFloatHeader              = { bg = palette.bg0, bold = palette.bold },
    NeogitFloatHeaderHighlight     = { bg = palette.bg2, fg = palette.cyan, bold = palette.bold },
    NeogitActiveItem               = { bg = palette.bg_orange, fg = palette.bg0, bold = palette.bold },
  }

  for group, hl in pairs(hl_store) do
    if not is_set(group) then
      hl.default = true
      vim.api.nvim_set_hl(0, group, hl)
    end
  end
end

return M
