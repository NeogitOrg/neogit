local M = {}
local git = require("neogit.lib.git")
local client = require("neogit.client")
local utils = require("neogit.lib.util")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local input = require("neogit.lib.input")
local notification = require("neogit.lib.notification")
local a = require("plenary.async")

function M.create_tag(popup)
  local tag_input = input.get_user_input("Tag name: ")
  local options = git.refs.get_revisions()
  local selected_branch = FuzzyFinderBuffer.new(options):open_async()
  if not selected_branch then
    return
  end
  local args = popup:get_arguments()
  if vim.tbl_count(args) > 0 and not vim.tbl_contains(args, "--annotate") then
    table.insert(args, "--annotate")
  end

  client.wrap(git.cli.tag.arg_list(utils.merge(args, { tag_input, selected_branch })), {
    autocmd = "NeogitTagComplete",
    msg = {
      success = "Added tag " .. tag_input .. " on " .. selected_branch,
      fail = "Failed to add tag " .. tag_input .. " on " .. selected_branch,
    },
  })
end

--- Create a release tag for `HEAD'.
---@param _ table
function M.create_release(_) end

--- Delete one or more tags.
--- If there are multiple tags then offer to delete those.
--- Otherwise prompt for a single tag to be deleted.
--- git tag -d TAGS
---@param _ table
function M.delete(_)
  local options = git.tag.list()
  local tags = {}
  if options ~= nil then
    local selected_tags = FuzzyFinderBuffer.new(options):open_async { allow_multi = true }
    if #selected_tags == 0 then
      return
    end
    tags = selected_tags
  else
    local tag_input = input.get_user_input("Tag name:")
    if not tag_input or tag_input == "" then
      return
    end
    table.insert(tags, tag_input)
  end

  local result = git.tag.delete(tags)
  a.util.scheduler()
  if result then
    notification.info("Deleted tags: " .. table.concat(tags, ","))
  end
end

--- Prunes differing tags from local and remote
---@param _ table
function M.prune(_)
  local remotes = git.remote.list()
  local selected_remote = FuzzyFinderBuffer.new(remotes)
    :open_async { prompt_prefix = "Prune tags using remote" }
  if not selected_remote or selected_remote == "" then
    return
  end
  local tags = git.tag.list()
  if tags == nil then
    return
  end
  local r_out = git.tag.list_remote(selected_remote)
  local remote_tags = {}
  -- Tags that exist locally put
  for _, line in ipairs(r_out) do
    if not line:match("%^{}$") then
      table.insert(remote_tags, line:sub(52))
    end
  end
  local l_tags = utils.set_difference(tags, remote_tags)
  local r_tags = utils.set_difference(remote_tags, tags)

  if #l_tags == 0 and #r_tags == 0 then
    a.util.scheduler()
    notification.info("Same tags exist locally and remotely")
    return
  end

  local choices = { "&delete all", "&review each", "&abort" }
  if #l_tags > 0 then
    local choice =
      input.get_choice(#l_tags .. " tags can be removed locally", { values = choices, default = #choices })
    if choice == "d" then
      l_tags = {}
    elseif choice == "r" then
      l_tags = utils.filter(l_tags, function(tag)
        return input.get_confirmation("Delete local tag: " .. tag)
      end)
    else
      return
    end
  end
  if #r_tags > 0 then
    local choice = input.get_choice(
      #r_tags .. " tags can be removed from remote",
      { values = choices, default = #choices }
    )
    if choice == "d" then
      r_tags = {}
    elseif choice == "r" then
      r_tags = utils.filter(r_tags, function(tag)
        return input.get_confirmation("Delete remote tag: " .. tag)
      end)
    else
      return
    end
  end

  if #l_tags > 0 then
    a.util.scheduler()
    notification.info("Pruned local tags:\n" .. table.concat(l_tags, "\n"))
    git.cli.tag.arg_list({ "-d", unpack(l_tags) }).call()
  end
  if #r_tags > 0 then
    local prune_tags = {}
    for _, tag in ipairs(r_tags) do
      table.insert(prune_tags, ":" .. tag)
    end
    a.util.scheduler()
    notification.info("Pruned remote tags: \n" .. table.concat(r_tags, "\n"))
    git.cli.push.arg_list({ selected_remote, unpack(prune_tags) }).call()
  end
end

return M
