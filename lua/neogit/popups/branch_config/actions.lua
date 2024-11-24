local a = require("plenary.async")
local git = require("neogit.lib.git")
local client = require("neogit.client")

local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {}

function M.remotes_for_config()
  local remotes = {}
  for _, name in ipairs(git.remote.list()) do
    table.insert(remotes, { display = name, value = name })
  end

  local pushDefault = git.config.get("remote.pushDefault")
  if pushDefault:is_set() then
    table.insert(remotes, { display = "remote.pushDefault:" .. pushDefault.value, value = "" })
  else
    table.insert(remotes, { display = "", value = "" })
  end

  return remotes
end

function M.merge_config(branch)
  local fn = function()
    -- When the values are set, clear them and return
    if git.config.get_local("branch." .. branch .. ".merge"):is_set() then
      git.config.set("branch." .. branch .. ".merge", nil)
      git.config.set("branch." .. branch .. ".remote", nil)

      return
    end

    local eventignore = vim.o.eventignore
    vim.o.eventignore = "WinLeave"
    local target = FuzzyFinderBuffer.new(git.refs.list_branches()):open_async {
      prompt_prefix = "upstream",
      refocus_status = false,
    }
    vim.o.eventignore = eventignore

    if not target then
      return
    end

    local merge_value, remote_value
    if target:match([[/]]) then
      local target_remote, target_branch = git.branch.parse_remote_branch(target)
      merge_value = "refs/heads/" .. target_branch
      remote_value = target_remote
    else
      merge_value = "refs/heads/" .. target
      remote_value = "."
    end

    git.config.set("branch." .. branch .. ".merge", merge_value)
    git.config.set("branch." .. branch .. ".remote", remote_value)

    return merge_value
  end

  return a.wrap(fn, 2)
end

function M.description_config(branch)
  local fn = function()
    vim.o.eventignore = "WinLeave"
    client.wrap(git.cli.branch.edit_description, {
      autocmd = "NeogitDescriptionComplete",
      msg = {
        success = "Description Updated",
      },
    })
    vim.o.eventignore = ""

    return git.config.get_local("branch." .. branch .. ".description"):read()
  end

  return a.wrap(fn, 2)
end

return M
