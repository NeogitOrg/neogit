local popup = require("neogit.lib.popup")
local notif = require("neogit.lib.notification")
local status = require("neogit.status")
local cli = require("neogit.lib.git.cli")
local a = require("plenary.async")

local M = {}

local function do_commit(popup, cmd)
  a.util.scheduler()

  local notification = notif.create("Committing...", vim.log.levels.INFO, 9999)

  local client = require("neogit.client")
  local envs = client.get_envs_git_editor()

  local result = cmd.env(envs).args(unpack(popup:get_arguments())).call(true):trim()

  a.util.scheduler()
  if notification then
    notification:delete()
  end

  if result.code == 0 then
    notif.create("Successfully committed!")
    vim.cmd("do <nomodeline> User NeogitCommitComplete")
  end

  a.util.scheduler()

  status.refresh(true, "do_commit")
end

function M.create()
  local p = popup
    .builder()
    :name("NeogitCommitPopup")
    :switch("a", "all", "Stage all modified and deleted files", false)
    :switch("e", "allow-empty", "Allow empty commit", false)
    :switch("v", "verbose", "Show diff of changes to be committed", false)
    :switch("h", "no-verify", "Disable hooks", false)
    :switch("s", "signoff", "Add Signed-off-by line", false)
    :switch("S", "no-gpg-sign", "Do not sign this commit", false)
    :switch("R", "reset-author", "Claim authorship and reset author date", false)
    :option("A", "author", "", "Override the author")
    :option("S", "gpg-sign", "", "Sign using gpg")
    :option("C", "reuse-message", "", "Reuse commit message")
    :action("c", "Commit", function(popup)
      do_commit(popup, cli.commit)
    end)
    :action("e", "Extend", function(popup)
      do_commit(popup, cli.commit.no_edit.amend)
    end)
    :action("w", "Reword", function(popup)
      do_commit(popup, cli.commit.amend.only)
    end)
    :action("a", "Amend", function(popup)
      do_commit(popup, cli.commit.amend)
    end)
    :new_action_group()
    :action("f", "Fixup")
    :action("s", "Squash")
    :action("A", "Augment")
    :new_action_group()
    :action("F", "Instant Fixup")
    :action("S", "Instant Squash")
    :build()

  p:show()

  return p
end

return M
