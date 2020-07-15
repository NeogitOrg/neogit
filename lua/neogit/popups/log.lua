local popup = require("neogit.lib.popup")
local util = require("neogit.lib.util")

local function create()
  popup.create(
    "NeogitLogPopup",
    {
      {
        key = "g",
        description = "Show graph",
        cli = "graph",
        enabled = true
      },
      {
        key = "c",
        description = "Show graph in color",
        cli = "color",
        enabled = true,
        parse = false
      },
      {
        key = "d",
        description = "Show refnames",
        cli = "decorate",
        enabled = true
      },
      {
        key = "S",
        description = "Show signatures",
        cli = "show-signature",
        enabled = false
      },
      {
        key = "u",
        description = "Show diffs",
        cli = "patch",
        enabled = false
      },
      {
        key = "s",
        description = "Show diffstats",
        cli = "stat",
        enabled = false
      },
      {
        key = "D",
        description = "Simplify by decoration",
        cli = "simplify-by-decoration",
        enabled = false
      },
      {
        key = "f",
        description = "Follow renames when showing single-file log",
        cli = "follow",
        enabled = false
      },
    },
    {
      {
        key = "n",
        description = "Limit number of commits",
        cli = "max-count",
        value = "256"
      },
      {
        key = "f",
        description = "Limit to files",
        cli = "-count",
        value = ""
      },
      {
        key = "a",
        description = "Limit to author",
        cli = "author",
        value = ""
      },
      {
        key = "g",
        description = "Search messages",
        cli = "grep",
        value = ""
      },
      {
        key = "G",
        description = "Search changes",
        cli = "",
        value = ""
      },
      {
        key = "S",
        description = "Search occurences",
        cli = "",
        value = ""
      },
      {
        key = "L",
        description = "Trace line evolution",
        cli = "",
        value = ""
      },
    },
    {
      {
        {
          key = "l",
          description = "Log current",
          callback = function(popup)
            local cmd = "git log " .. popup.to_cli()
            local output = vim.fn.systemlist(cmd)
            local output_len = #output

            local commits = {}

            for i=1,output_len do
              local matches = vim.fn.matchlist(output[i], "^[| ]*\\* .*commit \\(.*\\)")
              if #matches ~= 0 then
                local commit = {
                  hash = matches[2]
                }
                while true do
                  i = i + 1
                  matches = vim.fn.matchlist(output[i], "^\\(| \\?\\)\\+\\(.*\\)")
                  if #matches == 0 then
                    break;
                  end
                  print(matches[3])
                end
                table.insert(commits, commit)
                util.inspect(matches)
              end
            end

            print(#commits)

            vim.api.nvim_command("below new")

            local buf_handle = vim.api.nvim_get_current_buf()

            vim.api.nvim_buf_set_name(buf_handle, "NeogitLog")
            vim.api.nvim_buf_set_option(buf_handle, "buftype", "nofile")
            vim.api.nvim_buf_set_option(buf_handle, "bufhidden", "hide")
            vim.api.nvim_buf_set_option(buf_handle, "swapfile", false)

            vim.api.nvim_put(output, "l", false, false)

            vim.api.nvim_buf_set_option(buf_handle, "readonly", true)
            vim.api.nvim_buf_set_option(buf_handle, "modifiable", false)
            vim.api.nvim_buf_set_keymap(
              buf_handle,
              "n",
              "q",
              "<cmd>bw<CR>",
              {
                noremap = true,
                silent = true
              }
            )
          end
        },
        {
          key = "o",
          description = "Log other",
          callback = function() end
        },
        {
          key = "h",
          description = "Log HEAD",
          callback = function() end
        },
      },
      {
        {
          key = "L",
          description = "Log local branches",
          callback = function() end
        },
        {
          key = "b",
          description = "Log all branches",
          callback = function() end
        },
        {
          key = "a",
          description = "Log all references",
          callback = function() end
        },
      },
      {
        {
          key = "r",
          description = "Reflog current",
          callback = function() end
        },
        {
          key = "O",
          description = "Reflog other",
          callback = function() end
        },
        {
          key = "H",
          description = "Reflog HEAD",
          callback = function() end
        },
      }
    })
end

create()

return {
  create = create
}
