local logger = require("neogit.logger")
local process = require("neogit.process")
local util = require("neogit.lib.util")
local Path = require("plenary.path")

local function config(setup)
  setup = setup or {}
  setup.flags = setup.flags or {}
  setup.options = setup.options or {}
  setup.aliases = setup.aliases or {}
  setup.short_opts = setup.short_opts or {}
  return setup
end

local configurations = {
  show = config {
    flags = {
      stat = "--stat",
      oneline = "--oneline",
      no_patch = "--no-patch",
    },
    options = {
      format = "--format",
    },
    aliases = {
      file = function(tbl)
        return function(name, rev)
          return tbl.args((rev or "") .. ":" .. name)
        end
      end,
    },
  },

  init = config {},

  worktree = config {
    flags = {
      add = "add",
      list = "list",
      move = "move",
      remove = "remove",
    },
  },

  status = config {
    flags = {
      short = "-s",
      branch = "-b",
      verbose = "-v",
      null_separated = "-z",
    },
    options = {
      porcelain = "--porcelain",
    },
  },

  log = config {
    flags = {
      oneline = "--oneline",
      branches = "--branches",
      remotes = "--remotes",
      all = "--all",
      graph = "--graph",
      color = "--color",
    },
    options = {
      pretty = "--pretty",
      max_count = "--max-count",
      format = "--format",
    },
    aliases = {
      for_range = function(tbl)
        return function(range)
          return tbl.args(range)
        end
      end,
    },
  },

  config = config {
    flags = {
      _local = "--local",
      global = "--global",
      list = "--list",
      _get = "--get",
      _add = "--add",
      _unset = "--unset",
      null = "--null",
    },
    aliases = {
      set = function(tbl)
        return function(key, value)
          return tbl.arg_list { key, value }
        end
      end,
      unset = function(tbl)
        return function(key)
          return tbl._unset.args(key)
        end
      end,
      get = function(tbl)
        return function(path)
          return tbl._get.args(path)
        end
      end,
    },
  },

  describe = config {
    flags = {
      long = "--long",
      tags = "--tags",
    },
  },

  diff = config {
    flags = {
      cached = "--cached",
      shortstat = "--shortstat",
      patch = "--patch",
      name_only = "--name-only",
      no_ext_diff = "--no-ext-diff",
      no_index = "--no-index",
      check = "--check",
    },
  },

  stash = config {
    flags = {
      apply = "apply",
      drop = "drop",
      push = "push",
      store = "store",
      index = "--index",
    },
    aliases = {
      message = function(tbl)
        return function(text)
          return tbl.args("-m", text)
        end
      end,
    },
  },

  tag = config {
    flags = {
      n = "-n",
      list = "--list",
      delete = "--delete",
    },
  },

  rebase = config {
    flags = {
      interactive = "-i",
      onto = "--onto",
      edit_todo = "--edit-todo",
      continue = "--continue",
      abort = "--abort",
      skip = "--skip",
      autosquash = "--autosquash",
      autostash = "--autostash",
    },
    aliases = {
      commit = function(tbl)
        return function(rev)
          return tbl.args(rev .. "^")
        end
      end,
    },
  },

  merge = config {
    flags = {
      continue = "--continue",
      abort = "--abort",
    },
  },

  ["merge-base"] = config {
    flags = {
      is_ancestor = "--is-ancestor",
    },
  },

  reset = config {
    flags = {
      hard = "--hard",
      mixed = "--mixed",
      soft = "--soft",
      keep = "--keep",
      merge = "--merge",
    },
    aliases = {
      commit = function(tbl)
        return function(cm)
          return tbl.args(cm)
        end
      end,
    },
  },

  revert = config {
    flags = {
      no_commit = "--no-commit",
      continue = "--continue",
      skip = "--skip",
      abort = "--abort",
    },
  },

  checkout = config {
    short_opts = {
      b = "-b",
    },
    flags = {
      _track = "--track",
      detach = "--detach",
      ours = "--ours",
      theirs = "--theirs",
    },
    aliases = {
      track = function(tbl)
        return function(branch)
          return tbl._track.args(branch)
        end
      end,
      rev = function(tbl)
        return function(rev)
          return tbl.args(rev)
        end
      end,
      branch = function(tbl)
        return function(branch)
          return tbl.args(branch)
        end
      end,
      commit = function(tbl)
        return function(commit)
          return tbl.args(commit)
        end
      end,
      new_branch = function(tbl)
        return function(branch)
          return tbl.b(branch)
        end
      end,
      new_branch_with_start_point = function(tbl)
        return function(branch, start_point)
          return tbl.args(branch, start_point).b()
        end
      end,
      file = function(tbl)
        return function(file)
          return tbl.args(file)
        end
      end,
    },
  },

  remote = config {
    flags = {
      push = "--push",
      add = "add",
      rm = "rm",
      rename = "rename",
      prune = "prune",
    },
    aliases = {
      get_url = function(tbl)
        return function(remote)
          return tbl.args("get-url", remote)
        end
      end,
    },
  },

  apply = config {
    flags = {
      cached = "--cached",
      reverse = "--reverse",
      index = "--index",
    },
    aliases = {
      with_patch = function(tbl)
        return tbl.input
      end,
    },
  },

  add = config {
    flags = {
      update = "-u",
      all = "-A",
    },
  },

  commit = config {
    flags = {
      all = "--all",
      no_verify = "--no-verify",
      amend = "--amend",
      only = "--only",
      dry_run = "--dry-run",
      no_edit = "--no-edit",
      edit = "--edit",
      allow_empty = "--allow-empty",
    },
    aliases = {
      with_message = function(tbl)
        return function(message)
          return tbl.args("-F", "-").input(message)
        end
      end,
      message = function(tbl)
        return function(text)
          return tbl.args("-m", text)
        end
      end,
    },
    options = {
      commit_message_file = "--file",
    },
  },

  push = config {
    flags = {
      delete = "--delete",
    },
    aliases = {
      remote = function(tbl)
        return function(remote)
          return tbl.prefix(remote)
        end
      end,
      to = function(tbl)
        return function(to)
          return tbl.args(to)
        end
      end,
    },
  },

  pull = config {
    flags = {
      no_commit = "--no-commit",
    },
    pull = config {
      flags = {},
    },
  },

  cherry = config {
    flags = {
      verbose = "-v",
    },
  },

  branch = config {
    flags = {
      all = "-a",
      delete = "-d",
      remotes = "-r",
      force = "--force",
      current = "--show-current",
      edit_description = "--edit-description",
      very_verbose = "-vv",
      move = "-m",
    },
    aliases = {
      list = function(tbl)
        return function(sort)
          return tbl.args("--sort=" .. sort)
        end
      end,
      name = function(tbl)
        return function(name)
          return tbl.args(name)
        end
      end,
    },
  },

  fetch = config {
    options = {
      recurse_submodules = "--recurse-submodules",
      verbose = "--verbose",
    },
    aliases = {
      jobs = function(tbl)
        return function(n)
          return tbl.args("--jobs=" .. tostring(n))
        end
      end,
    },
  },

  ["read-tree"] = config {
    flags = {
      merge = "-m",
    },
    options = {
      index_output = "--index-output",
    },
    aliases = {
      tree = function(tbl)
        return function(tree)
          return tbl.args(tree)
        end
      end,
    },
  },

  ["write-tree"] = config {},

  ["commit-tree"] = config {
    flags = {
      no_gpg_sign = "--no-gpg-sign",
    },
    short_opts = {
      parent = "-p",
      message = "-m",
    },
    aliases = {
      parents = function(tbl)
        return function(...)
          for _, p in ipairs { ... } do
            tbl.parent(p)
          end
          return tbl
        end
      end,
      tree = function(tbl)
        return function(tree)
          return tbl.args(tree)
        end
      end,
    },
  },

  ["update-index"] = config {
    flags = {
      add = "--add",
      remove = "--remove",
      refresh = "--refresh",
    },
  },

  ["show-ref"] = config {
    flags = {
      verify = "--verify",
    },
  },

  ["show-branch"] = config {
    flags = {
      all = "--all",
    },
  },

  reflog = config {
    flags = {
      show = "show",
    },
    options = {
      format = "--format",
    },
    aliases = {
      date = function(tbl)
        return function(mode)
          return tbl.args("--date=" .. mode)
        end
      end,
    },
  },

  ["update-ref"] = config {
    flags = {
      create_reflog = "--create-reflog",
    },
    aliases = {
      message = function(tbl)
        return function(text)
          local escaped_text, _ = text:gsub([["]], [[\"]])
          return tbl.args("-m", string.format([["%s"]], escaped_text))
        end
      end,
    },
  },

  ["ls-files"] = config {
    flags = {
      others = "--others",
      deleted = "--deleted",
      modified = "--modified",
      cached = "--cached",
      deduplicate = "--deduplicate",
      exclude_standard = "--exclude-standard",
      full_name = "--full-name",
    },
  },

  ["ls-tree"] = config {
    flags = {
      full_tree = "--full-tree",
      name_only = "--name-only",
      recursive = "-r",
    },
  },

  ["ls-remote"] = config {
    flags = {
      tags = "--tags",
    },
    aliases = {
      remote = function(tbl)
        return function(remote)
          return tbl.args(remote)
        end
      end,
    },
  },

  ["for-each-ref"] = config {
    options = {
      format = "--format",
    },
  },

  ["rev-list"] = config {
    flags = {
      merges = "--merges",
      parents = "--parents",
    },
    options = {
      max_count = "--max-count",
    },
  },

  ["rev-parse"] = config {
    flags = {
      verify = "--verify",
      quiet = "--quiet",
      short = "--short",
      revs_only = "--revs-only",
      no_revs = "--no-revs",
      flags = "--flags",
      no_flags = "--no-flags",
      symbolic = "--symbolic",
      symbolic_full_name = "--symbolic-full-name",
    },
    options = {
      abbrev_ref = "--abbrev-ref",
    },
  },

  ["cherry-pick"] = config {
    flags = {
      no_commit = "--no-commit",
      continue = "--continue",
      skip = "--skip",
      abort = "--abort",
    },
  },

  ["verify-commit"] = config {},
}

-- NOTE: Use require("neogit.lib.git.repository").git_root instead of calling this function.
-- repository.git_root is used by all other library functions, so it's most likely the one you want to use.
-- git_root_of_cwd() returns the git repo of the cwd, which can change anytime
-- after git_root_of_cwd() has been called.
local function git_root_of_cwd()
  local job = require("plenary.job")
  local args = { "rev-parse", "--show-toplevel" }
  local gitdir = Path:new(vim.fn.getcwd()):absolute() -- default to current directory
  job
    :new({
      command = "git",
      args = args,
      on_exit = function(job_output, return_val)
        if return_val == 0 then
          -- Replace directory with the output of the git toplevel directory
          gitdir = Path:new(job_output:result()):absolute()
        else
          logger.warn("[CLI]: ", job_output:result())
        end
      end,
    })
    :sync()
  return gitdir
end

local is_inside_worktree = function(cwd)
  local job = require("plenary.job")
  local args = { "rev-parse", "--is-inside-work-tree" }
  local returnval = false
  if cwd then
    args = { "-C", cwd, "rev-parse", "--is-inside-work-tree" }
  end
  job
    :new({
      command = "git",
      args = args,
      on_exit = function(_, return_val)
        if return_val == 0 then
          returnval = true
        end
      end,
    })
    :sync()
  return returnval
end

local history = {}

---@param job any
---@param popup any
---@param hidden_text string Text to obfuscate from history
---@param hide_from_history boolean Do not show this command in GitHistoryBuffer
local function handle_new_cmd(job, popup, hidden_text, hide_from_history)
  if popup == nil then
    popup = true
  end

  if hide_from_history == nil then
    hide_from_history = false
  end

  table.insert(history, {
    cmd = hidden_text and job.cmd:gsub(hidden_text, string.rep("*", #hidden_text)) or job.cmd,
    raw_cmd = job.cmd,
    stdout = job.stdout,
    stderr = job.stderr,
    code = job.code,
    time = job.time,
    hidden = hide_from_history,
  })

  do
    local log_fn = logger.trace
    if job.code > 0 then
      log_fn = logger.warn
    end
    if job.code > 0 then
      log_fn(
        string.format("[CLI] Execution of '%s' failed with code %d after %d ms", job.cmd, job.code, job.time)
      )

      for _, line in ipairs(job.stderr) do
        if line ~= "" then
          log_fn(string.format("[CLI] [STDERR] %s", line))
        end
      end
    else
      log_fn(string.format("[CLI] Execution of '%s' succeeded in %d ms", job.cmd, job.time))
    end
  end
end

local k_state = {}
local k_config = {}
local k_command = {}

local mt_builder = {
  __index = function(tbl, action)
    if action == "args" or action == "arguments" then
      return function(...)
        for _, v in ipairs { ... } do
          table.insert(tbl[k_state].arguments, v)
        end
        return tbl
      end
    end

    if action == "arg_list" then
      return function(args)
        for _, v in ipairs(args) do
          table.insert(tbl[k_state].arguments, v)
        end
        return tbl
      end
    end

    if action == "files" or action == "paths" then
      return function(...)
        for _, v in ipairs { ... } do
          table.insert(tbl[k_state].files, v)
        end
        return tbl
      end
    end

    if action == "input" or action == "stdin" then
      return function(value)
        tbl[k_state].input = value
        return tbl
      end
    end

    if action == "prefix" then
      return function(x)
        tbl[k_state].prefix = x
        return tbl
      end
    end

    if action == "env" then
      return function(cfg)
        for k, v in pairs(cfg) do
          tbl[k_state].env[k] = v
        end
        return tbl
      end
    end

    if action == "show_popup" then
      return function(show_popup)
        tbl[k_state].show_popup = show_popup
        return tbl
      end
    end

    if action == "in_pty" then
      return function(in_pty)
        tbl[k_state].in_pty = in_pty
        return tbl
      end
    end

    if action == "hide_text" then
      return function(hide_text)
        tbl[k_state].hide_text = hide_text
        return tbl
      end
    end

    if tbl[k_config].flags[action] then
      table.insert(tbl[k_state].options, tbl[k_config].flags[action])
      return tbl
    end

    if tbl[k_config].options[action] then
      return function(value)
        if value then
          table.insert(tbl[k_state].options, string.format("%s=%s", tbl[k_config].options[action], value))
        else
          table.insert(tbl[k_state].options, tbl[k_config].options[action])
        end
        return tbl
      end
    end

    if tbl[k_config].short_opts[action] then
      return function(value)
        table.insert(tbl[k_state].options, tbl[k_config].short_opts[action])
        table.insert(tbl[k_state].options, value)
        return tbl
      end
    end

    if tbl[k_config].aliases[action] then
      return tbl[k_config].aliases[action](tbl, tbl[k_state])
    end

    error("unknown field: " .. action)
  end,
  __tostring = function(tbl)
    return string.format(
      "git %s %s %s -- %s",
      tbl[k_command],
      table.concat(tbl[k_state].options, " "),
      table.concat(tbl[k_state].arguments, " "),
      table.concat(tbl[k_state].files, " ")
    )
  end,
  __call = function(tbl, ...)
    return tbl.call(...)
  end,
}

---@param p Process
---@param line string
local function handle_interactive_password_questions(p, line)
  process.hide_preview_buffers()
  logger.debug(string.format("Matching interactive cmd output: '%s'", line))
  if vim.startswith(line, "Are you sure you want to continue connecting ") then
    logger.debug("[CLI]: Confirming whether to continue with unauthenticated host")
    local prompt = line
    local value = vim.fn.input {
      prompt = "The authenticity of the host can't be established. " .. prompt .. " ",
      cancelreturn = "__CANCEL__",
    }
    if value ~= "__CANCEL__" then
      logger.debug("[CLI]: Received answer")
      p:send(value .. "\r\n")
    else
      logger.debug("[CLI]: Cancelling the interactive cmd")
      p:stop()
    end
  elseif vim.startswith(line, "Username for ") then
    logger.debug("[CLI]: Asking for username")
    local prompt = line:match("(.*:?):.*")
    local value = vim.fn.input {
      prompt = prompt .. " ",
      cancelreturn = "__CANCEL__",
    }
    if value ~= "__CANCEL__" then
      logger.debug("[CLI]: Received username")
      p:send(value .. "\r\n")
    else
      logger.debug("[CLI]: Cancelling the interactive cmd")
      p:stop()
    end
  elseif vim.startswith(line, "Enter passphrase") or vim.startswith(line, "Password for") then
    logger.debug("[CLI]: Asking for password")
    local prompt = line:match("(.*:?):.*")
    local value = vim.fn.inputsecret {
      prompt = prompt .. " ",
      cancelreturn = "__CANCEL__",
    }
    if value ~= "__CANCEL__" then
      logger.debug("[CLI]: Received password")
      p:send(value .. "\r\n")
    else
      logger.debug("[CLI]: Cancelling the interactive cmd")
      p:stop()
    end
  else
    process.defer_show_preview_buffers()
    return false
  end

  process.defer_show_preview_buffers()
  return true
end

local function new_builder(subcommand)
  local configuration = configurations[subcommand]
  if not configuration then
    error("Command not found")
  end

  local state = {
    options = {},
    arguments = {},
    files = {},
    input = nil,
    show_popup = true,
    in_pty = false,
    env = {},
  }

  local function to_process(opts)
    local cmd = {}

    for _, o in ipairs(state.options) do
      table.insert(cmd, o)
    end

    for _, arg in ipairs(state.arguments) do
      if arg ~= "" then
        table.insert(cmd, arg)
      end
    end

    if #state.files > 0 then
      table.insert(cmd, "--")

      for _, f in ipairs(state.files) do
        table.insert(cmd, f)
      end
    end

    if state.prefix then
      table.insert(cmd, 1, state.prefix)
    end

    -- stylua: ignore
    cmd = util.merge(
      {
        "git",
        "--no-pager",
        "--literal-pathspecs",
        "--no-optional-locks",
        "-c", "core.preloadindex=true",
        "-c", "color.ui=always",
        subcommand
      },
      cmd
    )

    logger.trace(string.format("[CLI]: Executing '%s': '%s'", subcommand, table.concat(cmd, " ")))

    local repo = require("neogit.lib.git.repository")
    return process.new {
      cmd = cmd,
      cwd = repo.git_root,
      env = state.env,
      pty = state.in_pty,
      verbose = opts.verbose,
      on_error = opts.on_error,
    }
  end

  return setmetatable({
    [k_state] = state,
    [k_config] = configuration,
    [k_command] = subcommand,
    to_process = to_process,
    call_interactive = function(options)
      local opts = options or {}

      local handle_line = opts.handle_line or handle_interactive_password_questions
      local p = to_process {
        verbose = opts.verbose,
        on_error = function(_res)
          return true
        end,
      }
      p.pty = true

      p.on_partial_line = function(p, line, _)
        if line ~= "" then
          handle_line(p, line)
        end
      end

      local result = p:spawn_async(function()
        -- Required since we need to do this before awaiting
        if state.input then
          p:send(state.input)
        end
      end)

      assert(result, "Command did not complete")

      handle_new_cmd({
        cmd = table.concat(p.cmd, " "),
        stdout = result.stdout,
        stderr = result.stderr,
        code = result.code,
        time = result.time,
      }, state.show_popup, state.hide_text, opts.hidden)

      return result
    end,
    call = function(options)
      local opts = vim.tbl_extend(
        "keep",
        (options or {}),
        { verbose = false, ignore_error = not state.show_popup, hidden = false, trim = true }
      )

      local p = to_process {
        verbose = opts.verbose,
        on_error = function(res)
          local commit_aborted_msg = "hint: Waiting for your editor to close the file..."

          if vim.startswith(res.stdout[1], commit_aborted_msg) then
            return false
          end

          return not opts.ignore_error
        end,
      }

      local result = p:spawn_async(function()
        -- Required since we need to do this before awaiting
        if state.input then
          logger.debug("Sending input:" .. vim.inspect(state.input))
          -- Include EOT, otherwise git-apply will not work as expects the
          -- stream to end
          p:send(state.input .. "\04")
          p:close_stdin()
        end
      end)

      assert(result, "Command did not complete")

      handle_new_cmd({
        cmd = table.concat(p.cmd, " "),
        stdout = result.stdout,
        stderr = result.stderr,
        code = result.code,
        time = result.time,
      }, state.show_popup, state.hide_text, opts.hidden)

      if opts.trim then
        return result:trim()
      else
        return result
      end
    end,
    call_sync = function(options)
      local opts = vim.tbl_extend(
        "keep",
        (options or {}),
        { verbose = false, ignore_error = not state.show_popup, hidden = false, trim = true }
      )

      local p = to_process {
        on_error = function(_res)
          return not opts.ignore_error
        end,
      }

      if not p:spawn() then
        error("Failed to run command")
        return nil
      end

      local result = p:wait()
      assert(result, "Command did not complete")

      handle_new_cmd({
        cmd = table.concat(p.cmd, " "),
        stdout = result.stdout,
        stderr = result.stderr,
        code = result.code,
        time = result.time,
      }, state.show_popup, state.hide_text, opts.hidden)

      if opts.trim then
        return result:trim()
      else
        return result
      end
    end,
  }, mt_builder)
end

local meta = {
  __index = function(_, key)
    if configurations[key] then
      return new_builder(key)
    end

    error("unknown field: " .. key)
  end,
}

local cli = setmetatable({
  history = history,
  insert = handle_new_cmd,
  git_root_of_cwd = git_root_of_cwd,
  is_inside_worktree = is_inside_worktree,
}, meta)

return cli
