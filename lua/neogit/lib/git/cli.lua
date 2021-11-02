local notif = require("neogit.lib.notification")
local logger = require 'neogit.logger'
local a = require 'plenary.async'
local process = require('neogit.process')
local Job = require 'neogit.lib.job'
local util = require 'neogit.lib.util'
local split = require('neogit.lib.util').split

local function config(setup)
  setup = setup or {}
  setup.flags = setup.flags or {}
  setup.options = setup.options or {}
  setup.aliases = setup.aliases or {}
  setup.short_opts = setup.short_opts or {}
  return setup
end

local configurations = {
  show = config({
    flags = {
      stat = "--stat",
      oneline = "--oneline"
    },
    options = {
      format = "--format"
    },
    aliases = {
      file = function(tbl)
        return function(name, rev)
          return tbl.args((rev or "") .. ":" .. name)
        end
      end
    }
  }),
  status = config({
    flags = {
      short = "-s",
      branch = "-b",
      verbose = "-v",
      null_terminated = "-z"
    },
    options = {
      porcelain = "--porcelain",
    },
  }),
  log = config({
    flags = {
      oneline = "--oneline",
      branches = "--branches",
      remotes = "--remotes",
      all = "--all",
      graph = "--graph"
    },
    options = {
      pretty = "--pretty",
      max_count = "--max-count",
      format = "--format"
    },
    aliases = {
      for_range = function (tbl)
        return function (range)
          return tbl.args(range)
        end
      end
    }
  }),
  config = config({
    flags = {
      _get = "--get",
    },
    aliases = {
      get = function(tbl)
        return function(path)
          return tbl._get.args(path)
        end
      end
    }
  }),
  diff = config({
    flags = {
      null_terminated = '-z',
      cached = '--cached',
      shortstat = '--shortstat',
      patch = '--patch',
      name_only = '--name-only'
    },
  }),
  stash = config({
    flags = {
      apply = 'apply',
      drop = 'drop',
      index = '--index'
    }
  }),
  rebase = config({}),
  reset = config({
    flags = {
      hard = '--hard',
    },
    aliases = {
      commit = function (tbl)
        return function (cm)
          return tbl.args(cm)
        end
      end
    }
  }),
  checkout = config({
    short_opts = {
      b = '-b',
    },
    aliases = {
      branch = function (tbl)
        return function (branch)
          return tbl.args(branch)
        end
      end,
      new_branch = function (tbl)
        return function (branch)
          return tbl.b(branch)
        end
      end
    }
  }),
  remote = config({
    flags = {
      push = '--push'
    },
    aliases = {
      get_url = function (tbl)
        return function(remote)
          tbl.prefix("get-url")
          return tbl.args(remote)
        end
      end
    }
  }),
  apply = config({
    flags = {
      cached = '--cached',
      reverse = '--reverse',
      index = '--index'
    },
    aliases = {
      with_patch = function (tbl)
        return tbl.input
      end
    }
  }),
  add = config({
    flags = {
      update = '-u',
      all = '-A'
    },
  }),
  commit = config({
    flags = {
      amend = '--amend',
      only = '--only',
      dry_run = '--dry-run',
      no_edit = '--no-edit'
    },
    options = {
      commit_message_file = '--file'
    }
  }),
  push = config({
    flags = {
      delete = '--delete',
    },
    aliases = {
      remote = function (tbl)
        return function (remote)
          return tbl.prefix(remote)
        end
      end,
      to = function (tbl)
        return function (to)
          return tbl.args(to)
        end
      end
    }
  }),
  pull = config({
    flags = {
      no_commit = '--no-commit'
    },
  }),
  branch = config({
    flags = {
      list = '--list',
      all = '-a',
      delete = '-d',
      remotes = '-r',
      current = '--show-current',
      very_verbose = '-vv',
    },
    aliases = {
      name = function (tbl)
        return function (name)
          return tbl.args(name)
        end
      end
    }
  }),
  ['read-tree'] = config({
    flags = {
      merge = '-m'
    },
    options = {
      index_output = '--index-output'
    },
    aliases = {
      tree = function (tbl)
        return function (tree)
          return tbl.args(tree)
        end
      end
    }
  }),
  ['write-tree'] = config({}),
  ['commit-tree'] = config({
    flags = {
      no_gpg_sign = "--no-gpg-sign"
    },
    short_opts = {
      parent = "-p",
      message = "-m"
    },
    aliases = {
      parents = function (tbl)
        return function (...)
          for _, p in ipairs({...}) do
            tbl.parent(p)
          end
          return tbl
        end
      end,
      tree = function (tbl)
        return function (tree)
          return tbl.args(tree)
        end
      end
    }
  }),
  ['update-index'] = config({
    flags = {
      add = '--add',
      remove = '--remove'
    }
  }),
  ['show-ref'] = config({
    flags = {
      verify = '--verify',
    }
  }),
  ['update-ref'] = config({
    flags = {
      create_reflog = '--create-reflog'
    },
    short_opts = {
      message = '-m'
    }
  }),
  ['ls-files'] = config({
    flags = {
      others = '--others',
      deleted = '--deleted',
      modified = '--modified',
      cached = '--cached',
      full_name = '--full-name'
    },
  }),
  ['rev-parse'] = config({
    flags = {
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
  }),
}

local function git_root()
  return util.trim(process.spawn({cmd = 'git', args = {'rev-parse', '--show-toplevel'}}))
end

local git_root_sync = function()
  return util.trim(vim.fn.system("git rev-parse --show-toplevel"))
end

local git_dir_path_sync = function()
  return util.trim(vim.fn.system("git rev-parse --git-dir"))
end

local history = {}

local function handle_new_cmd(job, popup, hidden_text)
  if popup == nil then
    popup = true
  end

  table.insert(history, {
    cmd = hidden_text and job.cmd:gsub(hidden_text, string.rep("*", #hidden_text)) or job.cmd,
    raw_cmd = job.cmd,
    stdout = job.stdout,
    stderr = job.stderr,
    code = job.code,
    time = job.time
  })

  do
    local log_fn = logger.debug
    if job.code > 0 then
      log_fn = logger.error
    end
    log_fn(string.format("Execution of '%s'", job.cmd))
    if job.code > 0 then
      log_fn(string.format("  failed with code %d", job.code))
    end
    log_fn(string.format("  took %d ms", job.time))
  end

  if popup and job.code ~= 0 then
    vim.schedule(function ()
      notif.create("Git Error (" .. job.code .. "), press $ to see the git command history", vim.log.levels.ERROR)
    end)
  end
end

local function exec(cmd, args, cwd, stdin, env, show_popup, hide_text)
  args = args or {}
  if show_popup == nil then 
    show_popup = true 
  end
  table.insert(args, 1, cmd)

  if not cwd then
    cwd = git_root()
  elseif cwd == '<current>' then
    cwd = nil
  end

  local time = os.clock()
  local opts = {
    cmd = 'git',
    args = args,
    env = env,
    input = stdin,
    cwd = cwd
  }

  local result, code, errors = process.spawn(opts)
  local stdout = split(result, '\n')
  local stderr = split(errors, '\n')

  handle_new_cmd({
    cmd =  'git ' .. table.concat(args, ' '),
    stdout = stdout,
    stderr = stderr,
    code = code,
    time = os.clock() - time
  }, show_popup, hide_text)
  --print('git', table.concat(args, ' '), '->', code, errors)

  return stdout, code, stderr
end

local function new_job(cmd, args, cwd, _stdin, _env, show_popup, hide_text)
  args = args or {}
  if show_popup == nil then 
    show_popup = true 
  end
  table.insert(args, 1, cmd)

  if not cwd then
    cwd = git_root_sync()
  elseif cwd == '<current>' then
    cwd = nil
  end

  local cmd = "git " .. table.concat(args, ' ')
  local job = Job.new({ cmd = cmd })
  job.cwd = cwd

  handle_new_cmd(job, show_popup, hide_text)

  return job
end

local function exec_sync(cmd, args, cwd, stdin, env, show_popup, hide_text)
  local job = new_job(cmd, args, cwd, stdin, env, show_popup, hide_text)

  job:start()
  job:wait()

  return job.stdout, job.code, job.stderr
end

local k_state = {}
local k_config = {}
local k_command = {}

local mt_builder = {
  __index = function (tbl, action)
    if action == 'args' or action == 'arguments' then
      return function (...)
        for _, v in ipairs({...}) do
          table.insert(tbl[k_state].arguments, v)
        end
        return tbl
      end
    end

    if action == 'files' or action == 'paths' then
      return function (...)
        for _, v in ipairs({...}) do
          table.insert(tbl[k_state].files, v)
        end
        return tbl
      end
    end

    if action == 'input' or action == 'stdin' then
      return function (value)
        tbl[k_state].input = value
        return tbl
      end
    end

    if action == 'cwd' then
      return function (cwd)
        tbl[k_state].cwd = cwd
        return tbl
      end
    end

    if action == 'prefix' then
      return function (x)
        tbl[k_state].prefix = x
        return tbl
      end
    end

    if action == 'env' then
      return function (cfg)
        for k, v in pairs(cfg) do
          tbl[k_state].env[k] = v
        end
        return tbl
      end
    end

    if action == 'show_popup' then
      return function (show_popup)
        tbl[k_state].show_popup = show_popup
        return tbl
      end
    end

    if action == 'hide_text' then
      return function (hide_text)
        tbl[k_state].hide_text = hide_text
        return tbl
      end
    end

    if tbl[k_config].flags[action] then
      table.insert(tbl[k_state].options, tbl[k_config].flags[action])
      return tbl
    end

    if tbl[k_config].options[action] then
      return function (value)
        if value then
          table.insert(tbl[k_state].options, string.format("%s=%s", tbl[k_config].options[action], value))
        else
          table.insert(tbl[k_state].options, tbl[k_config].options[action])
        end
        return tbl
      end
    end

    if tbl[k_config].short_opts[action] then
      return function (value)
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
  __tostring = function (tbl)
    return string.format('git %s %s %s -- %s',
      tbl[k_command],
      table.concat(tbl[k_state].options, ' '),
      table.concat(tbl[k_state].arguments, ' '),
      table.concat(tbl[k_state].files, ' '))
  end,
  __call = function (tbl, ...)
    return tbl.call(...)
  end
}

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
    cwd = nil,
    env = {}
  }

  return setmetatable({
    [k_state] = state,
    [k_config] = configuration,
    [k_command] = subcommand,
    call = function ()
      local args = {}
      for _,o in ipairs(state.options) do 
        table.insert(args, o) 
      end
      for _,a in ipairs(state.arguments) do 
        table.insert(args, a) 
      end
      if #state.files > 0 then 
        table.insert(args, '--') 
      end
      for _,f in ipairs(state.files) do 
        table.insert(args, f) 
      end

      if state.prefix then
        table.insert(args, 1, state.prefix)
      end

      logger.debug(string.format("[CLI]: Executing '%s %s'", subcommand, table.concat(args, ' ')))

      return exec(subcommand, args, state.cwd, state.input, state.env, state.show_popup, state.hide_text)
    end,
    call_sync = function()
      local args = {}
      for _,o in ipairs(state.options) do 
        table.insert(args, o) 
      end
      for _,a in ipairs(state.arguments) do 
        table.insert(args, a) 
      end
      if #state.files > 0 then 
        table.insert(args, '--') 
      end
      for _,f in ipairs(state.files) do 
        table.insert(args, f) 
      end

      if state.prefix then
        table.insert(args, 1, state.prefix)
      end

      logger.debug(string.format("[CLI]: Executing '%s %s'", subcommand, table.concat(args, ' ')))

      return exec_sync(subcommand, args, state.cwd, state.input, state.env, state.show_popup, state.hide_text)
    end,
    to_job = function()
      local args = {}
      for _,o in ipairs(state.options) do 
        table.insert(args, o) 
      end
      for _,a in ipairs(state.arguments) do 
        table.insert(args, a) 
      end
      if #state.files > 0 then 
        table.insert(args, '--') 
      end
      for _,f in ipairs(state.files) do 
        table.insert(args, f) 
      end

      if state.prefix then
        table.insert(args, 1, state.prefix)
      end

      return new_job(subcommand, args, state.cwd, state.input, state.env, state.show_popup)
    end
  }, mt_builder)
end

local function new_parallel_builder(calls)
  local state = {
    calls = calls,
    show_popup = true,
    cwd = nil
  }

  local function call()
    if #state.calls == 0 then return end

    if not state.cwd then
      state.cwd = git_root()
    end
    if not state.cwd or state.cwd == "" then return end

    for _,c in ipairs(state.calls) do
      c.cwd(state.cwd).show_popup(state.show_popup)
    end

    local processes = {}
    for _, c in ipairs(state.calls) do
      table.insert(processes, c)
    end

    return a.util.join(processes)
  end

  return setmetatable({
    call = call
  }, {
    __index = function (tbl, action)
      if action == 'cwd' then
        return function (cwd)
          state.cwd = cwd
          return tbl
        end
      end

      if action == 'show_popup' then
        return function (show_popup)
          state.show_popup = show_popup
          return tbl
        end
      end
    end,
    __call = call
  })
end

local meta = {
  __index = function (_tbl, key)
    if configurations[key] then
      return new_builder(key)
    end

    error("unknown field")
  end
}

local function handle_interactive_password_questions(chan, line)
  logger.debug(string.format("Matching interactive cmd output: '%s'", line))
  if vim.startswith(line, "Are you sure you want to continue connecting ") then
    logger.debug "[CLI]: Confirming whether to continue with unauthenticated host"
    local prompt = line
    local value = vim.fn.input {
      prompt = "The authenticity of the host can't be established. " .. prompt .. " ",
      cancelreturn = "__CANCEL__"
    }
    if value ~= "__CANCEL__" then
      logger.debug "[CLI]: Received answer"
      vim.fn.chansend(chan, value .. "\n")
    else
      logger.debug "[CLI]: Cancelling the interactive cmd"
      vim.fn.chanclose(chan)
    end
  elseif vim.startswith(line, "Username for ") then
    logger.debug "[CLI]: Asking for username"
    local prompt = line:match("(.*:?):.*")
    local value = vim.fn.input {
      prompt = prompt .. " ",
      cancelreturn = "__CANCEL__"
    }
    if value ~= "__CANCEL__" then
      logger.debug "[CLI]: Received username"
      vim.fn.chansend(chan, value .. "\n")
    else
      logger.debug "[CLI]: Cancelling the interactive cmd"
      vim.fn.chanclose(chan)
    end
  elseif vim.startswith(line, "Enter passphrase") 
    or vim.startswith(line, "Password for") 
    then
    logger.debug "[CLI]: Asking for password"
    local prompt = line:match("(.*:?):.*")
    local value = vim.fn.inputsecret {
      prompt = prompt .. " ",
      cancelreturn = "__CANCEL__"
    }
    if value ~= "__CANCEL__" then
      logger.debug "[CLI]: Received password"
      vim.fn.chansend(chan, value .. "\n")
    else
      logger.debug "[CLI]: Cancelling the interactive cmd"
      vim.fn.chanclose(chan)
    end
  else
    return false
  end

  return true
end

local cli = setmetatable({
  history = history,
  insert = handle_new_cmd,
  git_root = git_root,
  interactive_git_cmd = a.wrap(function(cmd, handle_line, cb)
    handle_line = handle_line or handle_interactive_password_questions
    -- from: https://stackoverflow.com/questions/48948630/lua-ansi-escapes-pattern
    local ansi_escape_sequence_pattern = "[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]"
    local stdout = {}
    local raw_stdout = {}
    local chan
    local skip_count = 0

    local started_at = os.clock()
    logger.debug(string.format("[CLI]: Starting interactive git cmd '%s'", cmd))
    chan = vim.fn.jobstart(vim.fn.has('win32') == 1 and { "cmd", "/C", cmd } or cmd, {
      pty = true,
      width = 100,
      on_stdout = function(_, data)
        table.insert(raw_stdout, data)
        local is_end = #data == 1 and data[1] == ""
        if is_end then
          return
        end
        local data = table.concat(data, "")
        local data = data:gsub(ansi_escape_sequence_pattern, "")
        table.insert(stdout, data)
        local lines = vim.split(data, "\r?[\r\n]")

        for i=1,#lines do
          if lines[i] ~= "" then
            if skip_count > 0 then
              skip_count = skip_count - 1
            else
              handle_line(chan, lines[i])
            end
          end
        end
      end,
      on_exit = function(_, code)
        logger.debug(string.format("[CLI]: Interactive git cmd '%s' exited with code %d", cmd, code))
        handle_new_cmd {
          cmd = cmd,
          raw_cmd = cmd,
          stdout = stdout,
          stderr = stdout,
          code = code,
          time = (os.clock() - started_at) * 1000
        }
        cb({
          code = code,
          stdout = stdout
        })
      end,
    })

    if not chan then
      logger.error(string.format("[CLI]: Failed to start interactive git cmd ''", cmd))
    end
  end, 3),
  git_root_sync = git_root_sync,
  git_dir_path_sync = git_dir_path_sync,
  in_parallel = function(...)
    local calls = {...}
    return new_parallel_builder(calls)
  end,
}, meta)

return cli
