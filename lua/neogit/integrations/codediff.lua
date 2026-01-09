local M = {}

local git = require("neogit.lib.git")

---@param section_name string
---@param item_name    string|string[]|nil
---@param opts         table|nil
function M.open(section_name, item_name, opts)
  opts = opts or {}

  local codediff_git = require("codediff.core.git")
  local view = require("codediff.ui.view")

  -- Setup on_close callback using same BufEnter hack as diffview
  if opts.on_close then
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
      buffer = opts.on_close.handle,
      once = true,
      callback = opts.on_close.fn,
    })
  end

  local git_root = git.repo.worktree_root

  -- Map Neogit sections to codediff commands
  -- selene: allow(if_same_then_else)
  if section_name == "staged" or section_name == "unstaged" or section_name == "merge" then
    -- Explorer mode for local changes (like :CodeDiff with no args)
    codediff_git.get_status(git_root, function(err, status_result)
      if err then
        vim.schedule(function()
          vim.notify("codediff: " .. err, vim.log.levels.ERROR)
        end)
        return
      end

      vim.schedule(function()
        ---@type SessionConfig
        local session_config = {
          mode = "explorer",
          git_root = git_root,
          original_path = "",
          modified_path = "",
          original_revision = nil,
          modified_revision = nil,
          explorer_data = {
            status_result = status_result,
          },
        }
        view.create(session_config, "")
      end)
    end)
  elseif
    section_name == "recent"
    or section_name == "log"
    or (section_name and section_name:match("unmerged$"))
  then
    -- Commit diff (like :CodeDiff <commit>)
    local range
    if type(item_name) == "table" then
      range = { item_name[1], item_name[#item_name] }
    else
      local commit = item_name:match("[a-f0-9]+")
      range = { commit .. "^", commit }
    end

    codediff_git.get_diff_revisions(range[1], range[2], git_root, function(err, status_result)
      if err then
        vim.schedule(function()
          vim.notify("codediff: " .. err, vim.log.levels.ERROR)
        end)
        return
      end

      vim.schedule(function()
        ---@type SessionConfig
        local session_config = {
          mode = "explorer",
          git_root = git_root,
          original_path = "",
          modified_path = "",
          original_revision = range[1],
          modified_revision = range[2],
          explorer_data = {
            status_result = status_result,
          },
        }
        view.create(session_config, "")
      end)
    end)
  elseif section_name == "range" and item_name then
    -- Range diff (like :CodeDiff rev1 rev2)
    -- item_name is "rev1..rev2" or "rev1...rev2"
    local rev1, rev2 = item_name:match("([^.]+)%.%.%.?([^.]+)")
    if not rev1 then
      rev1, rev2 = item_name:match("([^.]+)%.%.([^.]+)")
    end

    if rev1 and rev2 then
      codediff_git.get_diff_revisions(rev1, rev2, git_root, function(err, status_result)
        if err then
          vim.schedule(function()
            vim.notify("codediff: " .. err, vim.log.levels.ERROR)
          end)
          return
        end

        vim.schedule(function()
          ---@type SessionConfig
          local session_config = {
            mode = "explorer",
            git_root = git_root,
            original_path = "",
            modified_path = "",
            original_revision = rev1,
            modified_revision = rev2,
            explorer_data = {
              status_result = status_result,
            },
          }
          view.create(session_config, "")
        end)
      end)
    end
  elseif (section_name == "stashes" or section_name == "commit") and item_name then
    -- Stash or commit diff
    local ref = item_name
    codediff_git.resolve_revision(ref, git_root, function(err_resolve, commit_hash)
      if err_resolve then
        vim.schedule(function()
          vim.notify("codediff: " .. err_resolve, vim.log.levels.ERROR)
        end)
        return
      end

      codediff_git.get_diff_revisions(commit_hash .. "^", commit_hash, git_root, function(err, status_result)
        if err then
          vim.schedule(function()
            vim.notify("codediff: " .. err, vim.log.levels.ERROR)
          end)
          return
        end

        vim.schedule(function()
          ---@type SessionConfig
          local session_config = {
            mode = "explorer",
            git_root = git_root,
            original_path = "",
            modified_path = "",
            original_revision = commit_hash .. "^",
            modified_revision = commit_hash,
            explorer_data = {
              status_result = status_result,
            },
          }
          view.create(session_config, "")
        end)
      end)
    end)
  elseif section_name == "conflict" then
    -- Conflict resolution mode
    if item_name then
      -- Single file conflict
      local file_path = type(item_name) == "string" and item_name or item_name[1]
      local relative_path = codediff_git.get_relative_path(git_root .. "/" .. file_path, git_root)
      local filetype = vim.filetype.match { filename = file_path } or ""

      ---@type SessionConfig
      local session_config = {
        mode = "standalone",
        git_root = git_root,
        original_path = relative_path,
        modified_path = relative_path,
        original_revision = ":3", -- theirs
        modified_revision = ":2", -- ours
        conflict = true,
      }
      view.create(session_config, filetype)
    else
      -- All conflicts - open explorer mode
      codediff_git.get_status(git_root, function(err, status_result)
        if err then
          vim.schedule(function()
            vim.notify("codediff: " .. err, vim.log.levels.ERROR)
          end)
          return
        end

        vim.schedule(function()
          ---@type SessionConfig
          local session_config = {
            mode = "explorer",
            git_root = git_root,
            original_path = "",
            modified_path = "",
            original_revision = nil,
            modified_revision = nil,
            explorer_data = {
              status_result = status_result,
            },
          }
          view.create(session_config, "")
        end)
      end)
    end
  elseif section_name == "worktree" or (section_name == nil and item_name == nil) then
    -- Worktree diff (all changes) - like :CodeDiff with no args
    codediff_git.get_status(git_root, function(err, status_result)
      if err then
        vim.schedule(function()
          vim.notify("codediff: " .. err, vim.log.levels.ERROR)
        end)
        return
      end

      vim.schedule(function()
        ---@type SessionConfig
        local session_config = {
          mode = "explorer",
          git_root = git_root,
          original_path = "",
          modified_path = "",
          original_revision = nil,
          modified_revision = nil,
          explorer_data = {
            status_result = status_result,
          },
        }
        view.create(session_config, "")
      end)
    end)
  elseif section_name == nil and item_name ~= nil then
    -- Direct commit reference
    local ref = item_name
    codediff_git.resolve_revision(ref, git_root, function(err_resolve, commit_hash)
      if err_resolve then
        vim.schedule(function()
          vim.notify("codediff: " .. err_resolve, vim.log.levels.ERROR)
        end)
        return
      end

      codediff_git.get_diff_revisions(commit_hash .. "^", commit_hash, git_root, function(err, status_result)
        if err then
          vim.schedule(function()
            vim.notify("codediff: " .. err, vim.log.levels.ERROR)
          end)
          return
        end

        vim.schedule(function()
          ---@type SessionConfig
          local session_config = {
            mode = "explorer",
            git_root = git_root,
            original_path = "",
            modified_path = "",
            original_revision = commit_hash .. "^",
            modified_revision = commit_hash,
            explorer_data = {
              status_result = status_result,
            },
          }
          view.create(session_config, "")
        end)
      end)
    end)
  end
end

return M
