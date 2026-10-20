local M = {}

local git = require("neogit.lib.git")
local client = require("neogit.client")
local utils = require("neogit.lib.util")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local input = require("neogit.lib.input")
local notification = require("neogit.lib.notification")
local event = require("neogit.lib.event")

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
    event.send("TagCreate", { name = tag_input, ref = selected })
  end
end

--- Extracts the version string from a tag name (e.g. "v1.2.3" → "1.2.3").
---@param tag string
---@return string|nil
local function extract_version(tag)
  return tag:match("%d[%d%.]*")
end

--- Derives a project name from the current working directory for use in tag messages.
--- e.g. "/path/to/foo-bar" → "Foo-Bar"
---@return string
local function project_name()
  local basename = vim.fn.fnamemodify(git.repo.worktree_root, ":t")
  local parts = {}
  for part in basename:gmatch("[^%-_]+") do
    table.insert(parts, part:sub(1, 1):upper() .. part:sub(2))
  end
  return table.concat(parts, "-")
end

--- Create a release tag for HEAD.
--- Prompts for a tag name using the highest existing tag as the default so the
--- user can simply increment the version. When --annotate is enabled, also
--- prompts for a message, proposing one derived from the previous tag's message
--- (with the old version replaced by the new one) or "Project-Name X.Y.Z".
---@param popup PopupData
function M.create_release(popup)
  local highest = git.tag.highest()

  local tag_name = input.get_user_input("Create release tag", {
    default = highest,
    strip_spaces = true,
    completion = "customlist,v:lua.require'neogit.lib.git'.refs.list_tags",
  })
  if not tag_name then
    return
  end

  local args = popup:get_arguments()
  local message

  if vim.tbl_contains(args, "--annotate") then
    local proposed

    if highest then
      local old_msg = git.tag.message(highest)
      local old_ver = extract_version(highest)
      local new_ver = extract_version(tag_name)

      if old_msg and old_ver and new_ver then
        proposed = old_msg:gsub(vim.pesc(old_ver), new_ver, 1)
      end
    end

    if not proposed then
      local ver = extract_version(tag_name)
      proposed = project_name() .. " " .. (ver or tag_name)
    end

    message = input.get_user_input("Tag message", { default = proposed })
    if not message then
      return
    end
  end

  local tag_args = utils.merge(args, { tag_name })
  if message then
    tag_args = utils.merge(tag_args, { "-m", message })
  end

  local code = client.wrap(git.cli.tag.arg_list(tag_args), {
    autocmd = "NeogitTagComplete",
    msg = {
      success = "Created release tag " .. tag_name,
      fail = "Failed to create release tag " .. tag_name,
    },
  })
  if code == 0 then
    event.send("TagCreate", { name = tag_name, ref = "HEAD" })
  end
end

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
      event.send("TagDelete", { name = tag })
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
