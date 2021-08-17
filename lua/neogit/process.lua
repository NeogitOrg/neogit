local a = require 'plenary.async'

local function trim_newlines(s)
  return (string.gsub(s, "^(.-)\n*$", "%1"))
end

local function spawn(options, cb)
  assert(options ~= nil, 'Options parameter must be given')
  assert(options.cmd, 'A command needs to be given!')

  local return_code, output, errors = nil, '', ''
  local stdin, stdout, stderr = vim.loop.new_pipe(false), vim.loop.new_pipe(false), vim.loop.new_pipe(false)
  local process_closed, stdout_closed, stderr_closed = false, false, false
  local function raise_if_fully_closed()
    if process_closed and stdout_closed and stderr_closed then
      cb(trim_newlines(output), return_code, trim_newlines(errors))
    end
  end

  local params = {
    stdio = {stdin, stdout, stderr},
  }

  if options.cwd then 
    params.cwd = options.cwd 
  end
  if options.args then 
    params.args = options.args 
  end
  if options.env and #options.env > 0 then
    params.env = {}
    -- setting 'env' completely overrides the parent environment, so we need to
    -- append all variables that are necessary for git to work in addition to
    -- all variables from passed object.
    table.insert(params.env, string.format('%s=%s', 'HOME', os.getenv('HOME')))
    table.insert(params.env, string.format('%s=%s', 'GNUPGHOME', os.getenv('GNUPGHOME')))
    for k, v in pairs(options.env) do
      table.insert(params.env, string.format('%s=%s', k, v))
    end
  end

  local handle, err
  handle, err = vim.loop.spawn(options.cmd, params, function (code, _)
    handle:close()
    --print('finished process', vim.inspect(params), vim.inspect({trim_newlines(output), errors}))

    return_code = code
    process_closed = true
    raise_if_fully_closed()
  end)
  --print('started process', vim.inspect(params), '->', handle, err, '@'..(params.cwd or '')..'@', options.input)
  if not handle then
    stdout:close()
    stderr:close()
    stdin:close()
    error(err)
  end

  vim.loop.read_start(stdout, function(err, data)
    assert(not err, err)
    if not data then
      stdout:read_stop()
      stdout:close()
      stdout_closed = true
      raise_if_fully_closed()
      return
    end

    --print('STDOUT', err, data)
    output = output .. data
  end)

  vim.loop.read_start(stderr, function (err, data)
    assert(not err, err)
    if not data then
      stderr:read_stop()
      stderr:close()
      stderr_closed = true
      raise_if_fully_closed()
      return
    end

    --print('STDERR', err, data)
    errors = errors .. (data or '')
  end)

  if options.input ~= nil then
    vim.loop.write(stdin, options.input)
  end

  stdin:close()
end

local M = {
  spawn = a.wrap(spawn, 2),
  spawn_sync = spawn
}

return M
