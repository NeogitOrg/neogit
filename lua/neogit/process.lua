local async = require'neogit.async'

local function trim_newlines(s)
  return (string.gsub(s, "^(.-)\n*$", "%1"))
end

local function spawn(options, cb)
  assert(options.cmd, 'A command needs to be given!')
  local cmd = options.cmd
  local stdin = vim.loop.new_pipe(false)
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)
  local output = ''
  local errors = ''

  local params = {
    stdio = {stdin, stdout, stderr},
  }

  if options.cwd then params.cwd = options.cwd end
  if options.args then params.args = options.args end

  local handle, err
  handle, err = vim.loop.spawn(cmd, params, function (code, _)
    stdout:read_stop()
    stdout:close()
    stderr:read_stop()
    stderr:close()
    handle:close()
    --print('finished process', vim.inspect(params), vim.inspect({trim_newlines(output), errors}))
    cb(trim_newlines(output), code, trim_newlines(errors))
  end)
  --print('started process', vim.inspect(options), '->', handle, err, '@'..(params.cwd or '')..'@')
  if not handle then
    error(err)
  end

  if options.input ~= nil then
    vim.loop.write(stdin, options.input)
    stdin:close()
  end

  vim.loop.read_start(stdout, function(err, data)
    --print('STDOUT', err, data)
    assert(not err, err)
    output = output .. (data or '')
  end)

  vim.loop.read_start(stderr, function (err, data)
    --print('STDERR', err, data)
    assert(not err, err)
    errors = errors .. (data or '')
  end)
end

return {
  spawn = async.wrap(spawn)
}
