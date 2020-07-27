local popup = require("neogit.lib.popup")
local cli = require("neogit.lib.git.cli")
local util = require("neogit.lib.util")
local buffer = require("neogit.buffer")
local mappings_manager = require("neogit.lib.mappings_manager")

local function create()
  popup.create(
    "NeogitCommitPopup",
    {
      {
        key = "a",
        description = "Stage all modified and deleted files",
        cli = "all",
        enabled = false
      },
      {
        key = "e",
        description = "Allow empty commit",
        cli = "allow-empty",
        enabled = false
      },
      {
        key = "v",
        description = "Show diff of changes to be committed",
        cli = "verbose",
        enabled = false
      },
      {
        key = "h",
        description = "Disable hooks",
        cli = "no-verify",
        enabled = false
      },
      {
        key = "s",
        description = "Add Signed-off-by line",
        cli = "signoff",
        enabled = false
      },
      {
        key = "R",
        description = "Claim authorship and reset author date",
        cli = "reset-author",
        enabled = false
      },
    },
    {
      {
        key = "A",
        description = "Override the author",
        cli = "author",
        value = ""
      },
      {
        key = "S",
        description = "Sign using gpg",
        cli = "gpg-sign",
        value = ""
      },
      {
        key = "C",
        description = "Reuse commit message",
        cli = "reuse-message",
        value = ""
      },
    },
    {
      {
        {
          key = "c",
          description = "Commit",
          callback = function(popup)
            local output = {
              "",
              "# Please enter the commit message for your changes. Lines starting",
              "# with '#' will be ignored, and an empty message aborts the commit."
            }

            for _, line in pairs(cli.run("status")) do
              if not vim.startswith(line, "  (") then
                table.insert(output, "# " .. line)
              end
            end

            buffer.create {
              name = ".git/COMMIT_EDITMSG",
              filetype = "gitcommit",
              modifiable = true,
              readonly = false,
              initialize = function(buf_handle, mmanager)
                vim.api.nvim_buf_set_lines(buf_handle, 0, -1, false, output)

                mmanager.mappings["control-c control-c"] = function()
                  vim.cmd([[
                    silent set buftype=
                    silent g/^#/d
                    silent w!
                    silent bw!
                  ]])
                  cli.run("commit -F .git/COMMIT_EDITMSG " .. popup.to_cli())
                  if cli.last_code == 0 then
                    __NeogitStatusRefresh()
                  end
                end
              end
            }
          end
        },
      },
      {
        {
          key = "e",
          description = "Extend",
          callback = function() end
        },
        {
          key = "w",
          description = "Reword",
          callback = function() end
        },
        {
          key = "a",
          description = "Amend",
          callback = function() end
        },
      },
      {
        {
          key = "f",
          description = "Fixup",
          callback = function() end
        },
        {
          key = "s",
          description = "Squash",
          callback = function() end
        },
        {
          key = "A",
          description = "Augment",
          callback = function() end
        },
      },
      {
        {
          key = "F",
          description = "Instant Fixup",
          callback = function() end
        },
        {
          key = "S",
          description = "Instant Squash",
          callback = function() end
        },
      }
    })
end

return {
  create = create
}
