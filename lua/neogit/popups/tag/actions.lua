local M = {}

local git = require("neogit.lib.git")
local client = require("neogit.client")
local utils = require("neogit.lib.util")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local input = require("neogit.lib.input")
local notification = require("neogit.lib.notification")

local function fire_tag_event(pattern, data)
  vim.api.nvim_exec_autocmds("User", { pattern = pattern, modeline = false, data = data })
end

---@param popup PopupData
function M.create_tag(popup)
  local tag_input = input.get_user_input("Create tag", {
    strip_spaces = true,
    completion = "customlist,v:lua.require'neogit.lib.git'.refs.list_tags",
  })
  if not tag_input then
    return
  end

  local selected
  if popup.state.env.commit then
    selected = popup.state.env.commit
  else
    selected = FuzzyFinderBuffer.new(git.refs.list()):open_async { prompt_prefix = "Create tag on" }
    if not selected then
      return
    end
  end

  local code =
    client.wrap(git.cli.tag.arg_list(utils.merge(popup:get_arguments(), { tag_input, selected })), {
      autocmd = "NeogitTagComplete",
      msg = {
        success = "Added tag " .. tag_input .. " on " .. selected,
        fail = "Failed to add tag " .. tag_input .. " on " .. selected,
      },
    })
  if code == 0 then
    fire_tag_event("NeogitTagCreate", { name = tag_input, ref = selected })
  end
end

--- Create a release tag for `HEAD'.
---@param _ table
function M.create_release(_) end

--- Delete one or more tags.
--- If there are multiple tags then offer to delete those.
--- Otherwise prompt for a single tag to be deleted.
--- git tag -d TAGS
---@param _ PopupData
function M.delete(_)
  local tags = FuzzyFinderBuffer.new(git.tag.list()):open_async { allow_multi = true }
  if #(tags or {}) == 0 then
    return
  end

  if git.tag.delete(tags) then
    notification.info("Deleted tags: " .. table.concat(tags, ","))
    for _, tag in pairs(tags) do
      fire_tag_event("NeogitTagDelete", { name = tag })
    end
  end
end

--- Prunes differing tags from local and remote
---@param _ PopupData
function M.prune(_)
  local tags = git.tag.list()
  if #tags == 0 then
    notification.info("No tags found")
    return
  end

  local selected_remote = FuzzyFinderBuffer.new(git.remote.list()):open_async {
    prompt_prefix = "Prune tags using remote",
  }
  if (selected_remote or "") == "" then
    return
  end

  notification.info("Fetching remote tags...")
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

  notification.delete_all()
  if #l_tags == 0 and #r_tags == 0 then
    notification.info("Tags are in sync - nothing to do.")
    return
  end

  local choices = { "&delete all", "&review each", "&abort" }

  if #l_tags > 0 then
    local choice =
      input.get_choice(#l_tags .. " tags can be removed locally", { values = choices, default = #choices })

    -- selene: allow(empty_if)
    if choice == "d" then
      -- No-op
    elseif choice == "r" then
      l_tags = utils.filter(l_tags, function(tag)
        vim.cmd.redraw()
        return input.get_permission("Delete local tag: " .. tag)
      end)
    else
      l_tags = {}
    end
  end

  if #r_tags > 0 then
    local choice = input.get_choice(
      #r_tags .. " tags can be removed from remote",
      { values = choices, default = #choices }
    )

    -- selene: allow(empty_if)
    if choice == "d" then
      -- no-op
    elseif choice == "r" then
      r_tags = utils.filter(r_tags, function(tag)
        vim.cmd.redraw()
        return input.get_permission("Delete remote tag: " .. tag)
      end)
    else
      r_tags = {}
    end
  end

  if #l_tags > 0 then
    notification.info("Pruned local tags:\n" .. table.concat(l_tags, "\n"))
    git.tag.delete(l_tags)
  end

  if #r_tags > 0 then
    local prune_tags = {}
    for _, tag in ipairs(r_tags) do
      table.insert(prune_tags, ":" .. tag)
    end

    git.cli.push.arg_list({ selected_remote, unpack(prune_tags) }).call()
    notification.info("Pruned remote tags: \n" .. table.concat(r_tags, "\n"))
  end
end

return M
