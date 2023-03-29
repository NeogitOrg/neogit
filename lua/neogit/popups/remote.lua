local popup = require("neogit.lib.popup")
local input = require("neogit.lib.input")
local git = require("neogit.lib.git")
local status = require("neogit.status")

local RemoteSelectViewBuffer = require("neogit.buffers.remote_select_view")

local M = {}

function M.create()
  local p = popup.builder()
    :name("NeogitRemotePopup")
    :switch("f", "f", "Fetch after add", true)
    :config("u", "remote.origin.url")
    :config("U", "remote.origin.fetch")
    :config("s", "remote.origin.pushurl")
    :config("S", "remote.origin.push")
    :config("O", "remote.origin.tagOpt", { "", "--no-tags", "--tags" })
    :group_heading("Actions")
    :action("a", "Add", function(popup)
      local name = input.get_user_input("Remote name: ")
      if not name then
        return
      end

      local origin = git.config.get("remote.origin.url").value
      local host, remote = origin:match("([^:/]+)[^/]+(.-%.git)")
      local remote_url = input.get_user_input("Remote url: ", host .. ":" .. name .. remote)
      if not remote_url then
        return
      end

      local result = git.remote.add(name, remote_url, popup:get_arguments())
      if result.code ~= 0 then
        return
      end

      local set_default = input.get_confirmation(
        [[Set 'remote.pushDefault' to "]] .. name .. [["?]],
        { values = { "&Yes", "&No" }, default = 2 }
      )

      if set_default then
        git.config.set("remote.pushDefault", name)
      end
    end)
    :action("r", "Rename", function()
      RemoteSelectViewBuffer.new(git.remote.list(), function(selected_remote)
        local new_name = input.get_user_input("Rename " .. selected_remote .. " to: ")
        if not new_name or new_name == "" then
          return
        end

        git.remote.rename(selected_remote, new_name)
        status.dispatch_refresh(true)
      end):open()
    end)
    :action("x", "Remove", function()
      RemoteSelectViewBuffer.new(git.remote.list(), function(selected_remote)
        git.remote.remove(selected_remote)
        status.dispatch_refresh(true)
      end):open()
    end)
    :new_action_group()
    :action("C", "Configure...", false)
    :action("p", "Prune stale branches", function()
      RemoteSelectViewBuffer.new(git.remote.list(), function(selected_remote)
        git.remote.prune(selected_remote)
        status.dispatch_refresh(true)
      end):open()
    end)
    :action("P", "Prune stale refspecs", false)
    -- https://github.com/magit/magit/blob/main/lisp/magit-remote.el#L159
    -- All of something's refspecs are stale.  replace with [d]efault refspec, [r]emove remote, or [a]abort
    :action("b", "Update default branch", false)
    -- https://github.com/magit/magit/blob/430a52c4b3f403ba8b0f97b4b67b868298dd60f3/lisp/magit-remote.el#L259
    :action("z", "Unshallow remote", false)
    -- https://github.com/magit/magit/blob/430a52c4b3f403ba8b0f97b4b67b868298dd60f3/lisp/magit-remote.el#L291
    :build()

  p:show()

  return p
end

return M
