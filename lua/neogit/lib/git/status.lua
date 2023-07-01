local git = {
  cli = require("neogit.lib.git.cli"),
  stash = require("neogit.lib.git.stash"),
}
local Collection = require("neogit.lib.collection")

local function update_file(file, mode, name)
  local mt, diff, has_diff
  if file then
    mt = getmetatable(file)
    has_diff = file.has_diff

    if rawget(file, "diff") then
      diff = file.diff
    end
  end

  return setmetatable({ mode = mode, name = name, has_diff = has_diff, diff = diff }, mt or {})
end

local function update_status(state)
  local result = git.cli.status.porcelain(2).branch.call_sync():trim()

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
        upstream.ref = value

        local remote, branch = unpack(vim.split(value, "/"))
        upstream.remote = remote
        upstream.branch = branch
      end
    else
      local kind, rest = l:match("(.) (.+)")
      if kind == "?" then
        table.insert(untracked_files, { name = rest })
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
          table.insert(staged_files, update_file(old_files_hash.staged_files[name], mode_staged, name))
        end

        if mode_unstaged ~= "." then
          table.insert(unstaged_files, update_file(old_files_hash.unstaged_files[name], mode_unstaged, name))
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

  if not upstream.ref or upstream.ref == state.upstream.ref then
    upstream.commit_message = state.upstream.commit_message
  end

  state.head = head
  state.upstream = upstream
  state.untracked.items = untracked_files
  state.unstaged.items = unstaged_files
  state.staged.items = staged_files
end

local function update_branch_information(state)
  if state.head.oid ~= "(initial)" then
    local result = git.cli.log.max_count(1).pretty("%B").call_sync():trim()
    state.head.commit_message = result.stdout[1]

    if state.upstream.ref then
      local result =
        git.cli.log.max_count(1).pretty("%B").for_range("@{upstream}").show_popup(false).call_sync():trim()
      state.upstream.commit_message = result.stdout[1]
    end
  end
end

local M = {}

function M.stage(...)
  require("neogit.lib.git.repository"):invalidate(...)
  git.cli.add.files(...).call()
end

function M.stage_modified()
  git.cli.add.update.call()
end

function M.stage_all()
  git.cli.add.all.call()
end

function M.unstage(...)
  require("neogit.lib.git.repository"):invalidate(...)
  git.cli.reset.files(...).call()
end

function M.unstage_all()
  git.cli.reset.call()
end

function M.register(meta)
  meta.update_status = update_status
  meta.update_branch_information = update_branch_information
end

return M
