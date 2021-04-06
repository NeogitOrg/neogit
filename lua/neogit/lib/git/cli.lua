local notif = require("neogit.lib.notification")
local a = require('plenary.async_lib')
local async, await, await_all = a.async, a.await, a.await_all
local process = require('neogit.process')
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
  status = config({
    flags = {
      short = "-s",
      branch = "-b",
      verbose = "-v"
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
      all = "--all"
    },
    options = {
      pretty = "--pretty",
      max_count = "--max-count"
    },
    aliases = {
      for_range = function (tbl)
        return function (range)
          return tbl.args(range)
        end
      end
    }
  }),
  diff = config({
    flags = {
      null_terminated = '-z',
      cached = '--cached',
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
  checkout = config({ }),
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
      no_edit = '--no-edit'
    },
    options = {
      commit_message_file = '--file'
    }
  }),
  push = config({ }),
  pull = config({
    flags = {
      no_commit = '--no-commit'
    },
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
  ['update-ref'] = config({
    flags = {
      create_reflog = '--create-reflog'
    },
    short_opts = {
      message = '-m'
    }
  })
}

local git_root = async(function()
  return vim.trim(await(process.spawn({cmd = 'git', args = {'rev-parse', '--show-toplevel'}})))
end)

local history = {}

local function handle_new_cmd(job, popup)
  if popup == nil then
    popup = true
  end

  table.insert(history, {
    cmd = job.cmd,
    stdout = job.stdout,
    stderr = job.stderr,
    code = job.code,
    time = job.time
  })

  if popup and job.code ~= 0 then
    vim.schedule(function ()
      notif.create({ "Git Error (" .. job.code .. ")!", "", "Press $ to see the git command history." }, { type = "error" })
    end)
  end
end

local exec = async(function(cmd, args, cwd, stdin, env, show_popup)
  args = args or {}
  if show_popup == nil then show_popup = true end
  table.insert(args, 1, cmd)

  local time = os.clock()
  local result, code, errors = await(process.spawn({
    cmd = 'git',
    args = args,
    env = env,
    input = stdin,
    cwd = cwd or await(git_root())
  }))
  handle_new_cmd({
    cmd =  'git ' .. table.concat(args, ' '),
    stdout = split(result, '\n'),
    stderr = split(errors, '\n'),
    code = code,
    time = os.clock() - time
  }, show_popup)
  --print('git', table.concat(args, ' '), '->', code, errors)

  return result, code, errors
end)

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
  if not configuration then error("Command not found") end

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
    call = async(function ()
      local args = {}
      for _,o in ipairs(state.options) do table.insert(args, o) end
      for _,a in ipairs(state.arguments) do table.insert(args, a) end
      if #state.files > 0 then table.insert(args, '--') end
      for _,f in ipairs(state.files) do table.insert(args, f) end

      return await(exec(subcommand, args, state.cwd, state.input, state.env, state.show_popup))
    end)
  }, mt_builder)
end

local function new_parallel_builder(calls)
  local state = {
    calls = calls,
    show_popup = true,
    cwd = nil
  }

  local call = async(function ()
    if #state.calls == 0 then return end

    if not state.cwd then
      state.cwd = await(git_root())
    end
    if not state.cwd or state.cwd == "" then return end

    for _,c in ipairs(state.calls) do
      c.cwd(state.cwd).show_popup(state.show_popup)
    end

    local processes = {}
    for _,c in ipairs(state.calls) do
      table.insert(processes, c())
    end

    return await_all(processes)
  end)

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
  __index = function (tbl, key)
    if configurations[key] then
      return new_builder(key)
    end

    error("unknown field")
  end
}

local cli = setmetatable({
  history = history,
  in_parallel = function(...)
    local calls = {...}
    return new_parallel_builder(calls)
  end
}, meta)

return cli
