local M = {}

local git = require("neogit.lib.git")
local util = require("neogit.lib.util")

local LogViewBuffer = require("neogit.buffers.log_view")
local ReflogViewBuffer = require("neogit.buffers.reflog_view")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local operation = require("neogit.operations")

---Builds a graph for the popup if required
---@param popup table Contains the argument list
---@param flags table extra CLI flags like --branches or --remotes
---@return table|nil
local function maybe_graph(popup, flags)
  local args = popup:get_internal_arguments()
  if args.graph then
    local external_args = popup:get_arguments()
    util.remove_item_from_table(external_args, "--show-signature")

    return git.log.graph(util.merge(external_args, flags), popup.state.env.files, args.color)
  end
end

--- Runs `git log` and parses the commits
---@param popup table Contains the argument list
---@param flags table extra CLI flags like --branches or --remotes
---@return CommitLogEntry[]
local function commits(popup, flags)
  return git.log.list(
    util.merge(popup:get_arguments(), flags),
    maybe_graph(popup, flags),
    popup.state.env.files
  )
end

-- TODO: Handle when head is detached
M.log_current = operation("log_current", function(popup)
  LogViewBuffer.new(commits(popup, {}), popup:get_internal_arguments()):open()
end)

function M.log_head(popup)
  LogViewBuffer.new(commits(popup, { "HEAD" }), popup:get_internal_arguments()):open()
end

function M.log_local_branches(popup)
  LogViewBuffer.new(
    commits(popup, { git.branch.is_detached() and "" or "HEAD", "--branches" }),
    popup:get_internal_arguments()
  ):open()
end

function M.log_other(popup)
  local branch = FuzzyFinderBuffer.new(git.branch.get_local_branches()):open_async()
  if branch then
    LogViewBuffer.new(commits(popup, { branch }), popup:get_internal_arguments()):open()
  end
end

function M.log_all_branches(popup)
  LogViewBuffer.new(
    commits(popup, { git.branch.is_detached() and "" or "HEAD", "--branches", "--remotes" }),
    popup:get_internal_arguments()
  ):open()
end

function M.log_all_references(popup)
  LogViewBuffer.new(
    commits(popup, { git.branch.is_detached() and "" or "HEAD", "--all" }),
    popup:get_internal_arguments()
  )
    :open()
end

function M.reflog_current(popup)
  ReflogViewBuffer.new(git.reflog.list(git.branch.current(), popup:get_arguments())):open()
end

function M.reflog_head(popup)
  ReflogViewBuffer.new(git.reflog.list("HEAD", popup:get_arguments())):open()
end

function M.reflog_other(popup)
  local branch = FuzzyFinderBuffer.new(git.branch.get_local_branches()):open_async()
  if branch then
    ReflogViewBuffer.new(git.reflog.list(branch, popup:get_arguments())):open()
  end
end

-- TODO: Prefill the fuzzy finder with the filepath under cursor, if there is one
---comment
---@param popup Popup
---@param option table
---@param set function
---@return nil
function M.limit_to_files(popup, option, set)
  local a = require("plenary.async")

  a.run(function()
    if option.value ~= "" then
      popup.state.env.files = nil
      set("")
      return
    end

    local files = FuzzyFinderBuffer.new(git.files.all_tree()):open_async {
      allow_multi = true,
      refocus_status = false,
    }

    if not files or vim.tbl_isempty(files) then
      popup.state.env.files = nil
      set("")
      return
    end

    popup.state.env.files = files
    files = util.map(files, function(file)
      return string.format([[ "%s"]], file)
    end)

    set(table.concat(files, ""))
  end)
end

return M
