local co = coroutine

local function execute_coroutine_async(thread, cb)
  local function next(...)
    local result = {co.resume(thread, ...)}
    local status = result[1]

    if not status then error(result[2], 3)
    elseif co.status(thread) ~= "dead" then result[2](next)
    else
      local returns = {}
      for i = 2, #result do
        table.insert(returns, result[i])
      end
      (cb or function() end)(unpack(returns))
    end
  end
  return next
end

local function wrap(func)
  return function(...)
    local args = {...}
    return function(cb)
      table.insert(args, cb)
      return func(unpack(args))
    end
  end
end

local function join_any(funcs, resolver)
  local results = {}
  local count_finished = 0

  return function (step)
    if #funcs == 0 then return step({}) end

    for i, func in ipairs(funcs) do
      func(function (...)
        results[i] = resolver(...)
        count_finished = count_finished + 1

        if count_finished == #funcs then
          step(unpack(results))
        end
      end)
    end
  end
end

local function sync(func)
  return function (...)
    local args = {...}
    return function (cb)
      local thread = co.create(func)
      execute_coroutine_async(thread, cb)(unpack(args, 1, table.maxn(args)))
    end
  end
end

return {
  sync = sync,
  wait = function(defer)
    return co.yield(defer)
  end,
  wait_all = function (defer)
    return co.yield(join_any(defer, function (first) return first end))
  end,
  wait_map_all = function (defer, mapper)
    return co.yield(join_any(defer, mapper))
  end,
  dispatch = function (func)
    sync(func)()(function () end)
  end,
  run = function (async, ...)
    async(...)(function () end)
  end,
  wrap = wrap,
  wait_for_textlock = function ()
    return co.yield(vim.schedule)
  end
}

