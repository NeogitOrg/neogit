local git = {
  cli = require("neogit.lib.git.cli"),
  stash = require("neogit.lib.git.stash"),
}
local a = require("plenary.async")
local Collection = require("neogit.lib.collection")

local function update_status(state)
  -- git-status outputs files relative to the cwd.
  --
  -- Save the working directory to allow resolution to absolute paths since the
  -- cwd may change after the status is refreshed and used, especially if using
  -- rooter plugins with lsp integration
  local cwd = vim.fn.getcwd()
  local result = git.cli.status.porcelain(2).branch.call():trim()

  local untracked_files, unstaged_files, staged_files = {}, {}, {}
  local old_files_hash = {
    staged_files = Collection.new(state.staged.items or {}):key_by("name"),
    unstaged_files = Collection.new(state.unstaged.items or {}):key_by("name"),
  }

  local head = {}
  local upstream = {}

  for _, l in ipairs(result.stdout) do
    local header, value = l:match("# ([%w%.]+) (.+)")
    if header then
      if header == "branch.head" then
        head.branch = value
      elseif header == "branch.oid" then
        head.oid = value
      elseif header == "branch.upstream" then
        upstream.branch = value
      end
    else
      local kind, rest = l:match("(.) (.+)")
      if kind == "?" then
        table.insert(untracked_files, {
          name = rest,
        })
      elseif kind == "u" then
        local mode, _, _, _, _, _, _, _, _, name =
          rest:match("(..) (....) (%d+) (%d+) (%d+) (%d+) (%w+) (%w+) (%w+) (.+)")
        table.insert(untracked_files, {
          mode = mode,
          name = name,
        })
        -- selene: allow(empty_if)
      elseif kind == "!" then
        -- we ignore ignored files for now
      elseif kind == "1" then
        local mode_staged, mode_unstaged, _, _, _, _, _, _, name =
          rest:match("(.)(.) (....) (%d+) (%d+) (%d+) (%w+) (%w+) (.+)")
        if mode_staged ~= "." then
          table.insert(staged_files, {
            mode = mode_staged,
            name = name,
            diff = old_files_hash.staged_files[name] and old_files_hash.staged_files[name].diff,
          })
        end
        if mode_unstaged ~= "." then
          table.insert(unstaged_files, {
            mode = mode_unstaged,
            name = name,
            diff = old_files_hash.unstaged_files[name] and old_files_hash.unstaged_files[name].diff,
          })
        end
      elseif kind == "2" then
        local mode_staged, mode_unstaged, _, _, _, _, _, _, _, name, orig_name =
          rest:match("(.)(.) (....) (%d+) (%d+) (%d+) (%w+) (%w+) (%a%d+) ([^\t]+)\t?(.+)")
        local entry = {
          name = name,
        }

        if mode_staged ~= "." then
          entry.mode = mode_staged
          table.insert(staged_files, entry)
        end
        if mode_unstaged ~= "." then
          entry.mode = mode_unstaged
          table.insert(unstaged_files, entry)
        end

        if orig_name ~= nil then
          entry.original_name = orig_name
        end
      end
    end
  end

  if not state.head.branch or head.branch == state.head.branch then
    head.commit_message = state.head.commit_message
  end
  if not upstream.branch or upstream.branch == state.upstream.branch then
    upstream.commit_message = state.upstream.commit_message
  end

  state.cwd = cwd
  state.head = head
  state.upstream = upstream
  state.untracked.items = untracked_files
  state.unstaged.items = unstaged_files
  state.staged.items = staged_files
end

local function update_branch_information(state)
  local tasks = {}

  if state.head.oid ~= "(initial)" then
    table.insert(tasks, function()
      local result = git.cli.log.max_count(1).pretty("%B").call():trim()
      state.head.commit_message = result.stdout[1]
    end)

    if state.upstream.branch then
      table.insert(tasks, function()
        local result =
          git.cli.log.max_count(1).pretty("%B").for_range("@{upstream}").show_popup(false).call():trim()
        state.upstream.commit_message = result.stdout[1]
      end)
    end
  end

  if #tasks > 0 then
    a.util.join(tasks)
  end
end

local status = {
  stage = function(name)
    git.cli.add.files(name).call()
  end,
  stage_modified = function()
    git.cli.add.update.call()
  end,
  stage_all = function()
    git.cli.add.all.call()
  end,
  unstage = function(name)
    git.cli.reset.files(name).call()
  end,
  unstage_all = function()
    git.cli.reset.call()
  end,
}

status.register = function(meta)
  meta.update_status = update_status
  meta.update_branch_information = update_branch_information
end

return status
