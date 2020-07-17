local cli = require("neogit.lib.git.cli")

local branch_re = "On branch \\(\\w\\+\\)"
local remote_re = "Your branch \\(is up to date with\\|is ahead of\\|is behind\\|and\\) '\\(.*\\)' \\?\\(by \\(\\d*\\) commit\\|have diverged\\)\\?"
local change_re = "\\W*\\(.*\\):\\W*\\(.*\\)"

return {
  get = function()
    local output = cli.run("status")
    local lineidx = 1

    local function parse_current_line(regex)
      return vim.fn.matchlist(output[lineidx], regex)
    end

    local function parse_changes(list)
      while output[lineidx] ~= "" do
        local matches = parse_current_line(change_re)

        table.insert(list, {
            type = matches[2],
            name = matches[3],
            diff_open = false,
            diff_height = 0
          })

        lineidx = lineidx + 1
      end
    end

    local function skip_explanation()
      while string.find(output[lineidx], "\t") == nil do
        lineidx = lineidx + 1
      end
    end

    local result = {}

    result.staged_changes = {}
    result.unstaged_changes = {}
    result.untracked_files = {}
    result.ahead_by = 0
    result.behind_by = 0
    result.branch = parse_current_line(branch_re)[2]
    lineidx = lineidx + 1

    local matches = parse_current_line(remote_re)

    if matches[2] == "is ahead of" then
      result.ahead_by = tonumber(matches[5])
    elseif matches[2] == "is behind" then
      result.behind_by = tonumber(matches[5])
    elseif matches[2] == "and" then
      lineidx = lineidx + 1
      matches = parse_current_line("and have \\(\\d*\\) and \\(\\d*\\)")
      result.ahead_by = tonumber(matches[2])
      result.behind_by = tonumber(matches[3])
    end

    result.remote = matches[3]
    lineidx = lineidx + 1

    while output[lineidx] ~= "" do
      lineidx = lineidx + 1
    end

    lineidx = lineidx + 1

    if output[lineidx] == "You are currently rebasing." then
      lineidx = lineidx + 2
      lineidx = lineidx + 1
    end

    if output[lineidx] == "Changes to be committed:" then
      skip_explanation()

      parse_changes(result.staged_changes)

      lineidx = lineidx + 1
    end

    if output[lineidx] == "Changes not staged for commit:" then
      skip_explanation()

      parse_changes(result.unstaged_changes)

      lineidx = lineidx + 1
    end

    if output[lineidx] == "Untracked files:" then
      skip_explanation()

      while output[lineidx] ~= "" do
        local file = string.sub(output[lineidx], 2)
        table.insert(result.untracked_files, { name = file, diff_height = 0, diff_open = false })
        lineidx = lineidx + 1
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

