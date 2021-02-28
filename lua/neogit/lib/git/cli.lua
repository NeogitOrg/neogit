local notif = require("neogit.lib.notification")
local a = require('neogit.async')
local process = require('neogit.process')
local split = require('neogit.lib.util').split

local function config(setup)
  setup = setup or {}
  setup.flags = setup.flags or {}
  setup.options = setup.options or {}
  setup.aliases = setup.aliases or {}
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
      cached = '--cached',
    },
  }),
  stash = config({ }),
  reset = config({ }),
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
  })
}

local git_root = a.sync(function()
  return vim.trim(a.wait(process.spawn({cmd = 'git', args = {'rev-parse', '--show-toplevel'}})))
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

local exec = a.sync(function(cmd, args, cwd, stdin)
  args = args or {}
  table.insert(args, 1, cmd)

  local time = os.clock()
  local result, code, errors = a.wait(process.spawn({
    cmd = 'git',
    args = args,
    input = stdin,
    cwd = cwd or a.wait(git_root())
  }))
  handle_new_cmd({
    cmd =  'git ' .. table.concat(args, ' '),
    stdout = split(result, '\n'),
    stderr = split(errors, '\n'),
    code = code,
    time = os.clock() - time
  }, true)
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
    cwd = nil
  }

  return setmetatable({
    [k_state] = state,
    [k_config] = configuration,
    [k_command] = subcommand,
    call = a.sync(function ()
      local args = {}
      for _,o in ipairs(state.options) do table.insert(args, o) end
      for _,a in ipairs(state.arguments) do table.insert(args, a) end
      table.insert(args, '--')
      for _,f in ipairs(state.files) do table.insert(args, f) end

      return a.wait(exec(subcommand, args, state.cwd, state.input))
    end)
  }, mt_builder)
end

local function new_parallel_builder(calls)
  local state = {
    calls = calls,
    cwd = nil
  }

  local call = a.sync(function ()
    if #state.calls == 0 then return end

    if not state.cwd then
      state.cwd = a.wait(git_root())
    end
    if not state.cwd or state.cwd == "" then return end

    for _,c in ipairs(state.calls) do
      c.cwd(state.cwd)
    end

    local processes = {}
    for _,c in ipairs(state.calls) do
      table.insert(processes, c())
    end

    return a.wait_all(processes)
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
