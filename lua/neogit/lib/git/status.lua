local cli = require("neogit.lib.git.cli")

local status = {
  get = function()
    local output = cli.run("status --porcelain=1 --branch")

    for _, line in pairs(output) do
      local matches = vim.fn.matchlist(line, "\\(.\\{2}\\) \\(.*\\)")
      local marker = matches[2]
      local details = matches[3]

      if marker == "##" then
        matches = vim.fn.matchlist(details, "^\\([a-zA-Z0-9]*\\)...\\(\\S*\\)\\%( \\[\\(ahead\\|behind\\) \\([0-9]*\\)\\]\\)*$")
        print(vim.inspect(matches))
      elseif marker == "??" then
        print(details .. " is untracked")
      else
        local chars = vim.split(marker, "")
        if chars[1] == " " then
          print(details .. " is not staged")
        else
          print(details .. " is staged")
        end
      end
    end

    return result
  end,
  stage = function(name)
    cli.run("add " .. name)
  end,
  stage_modified = function()
    cli.run("add -u")
  end,
  stage_all = function()
    cli.run("add -A")
  end,
  unstage = function(name)
    cli.run("reset " .. name)
  end,
  unstage_all = function()
    cli.run("reset")
  end,
}

status.get()

return status
