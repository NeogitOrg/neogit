package.loaded['neogit.lib.popup.lib'] = nil

local a = require 'plenary.async'
local util = require("neogit.lib.util")

local popups = {}

local function use_highlight(h)
  if h.enabled then
    h.id = vim.fn.matchaddpos("SpecialChar", { { h.line, h.col, h.length } })
  else
    h.id = vim.fn.matchaddpos("Comment", { { h.line, h.col, h.length } })
  end
end

local function draw_popup(popup)
  local output = {}

  popup.highlights = {}

  table.insert(output, "Switches")

  for _, switch in pairs(popup.switches) do
    table.insert(output, string.format(" -%s %s (--%s)", switch.key, switch.description, switch.cli))
    popup.highlights["-" .. switch.key] = {
      line = #output,
      col = 6 + #switch.key + #switch.description,
      length = 2 + #switch.cli,
      id = 0,
      enabled = switch.enabled
    }
  end

  table.insert(output, "")
  table.insert(output, "Options")

  for _, option in pairs(popup.options) do
    table.insert(output, string.format(" =%s %s (--%s=)", option.key, option.description, option.cli))
    popup.highlights["=" .. option.key] = {
      line = #output,
      col = 6 + #option.key + #option.description,
      length = 3 + #option.cli,
      id = 0,
      enabled = #option.value ~= 0
    }
  end

  table.insert(output, "")

  table.insert(output, "Actions")

  local columns = {}
  local actions_grid_height = 0

  for _, col in pairs(popup.actions) do
    -- max width of key
    local k_width = 0
    -- max width of description
    local d_width = 0

    -- calculate width for column
    for i, item in pairs(col) do
      if i > actions_grid_height then
        actions_grid_height = i
      end
      if k_width < #item.key then
        k_width = #item.key
      end
      if d_width < #item.description then
        d_width = #item.description
      end
    end

    table.insert(columns, {
        k_width = k_width,
        d_width = d_width,
        items = col
    })
  end

  for i=1,actions_grid_height do
    local result = " "
    for index, col in pairs(columns) do
      local item = col.items[i]

      local next_col = columns[index + 1]
      local has_neighbour = next_col and col.items and item and next_col.items[i]

      if item == nil then
        local key = next_col and util.str_right_pad("", col.k_width + 1, " ") or ""
        local description =  next_col
          and util.str_right_pad("", col.d_width + 6, " ")
          or ""

        result = result .. key .. description
      else
        local key = util.str_right_pad(item.key, col.k_width + 1, " ")
        local description = has_neighbour
          and util.str_right_pad(item.description, col.d_width + 6, " ")
          or item.description

        result = result .. key .. description
      end
    end
    table.insert(output, result)
  end

  vim.api.nvim_put(output, "l", false, false)

  popup.action_highlight = vim.fn.matchadd("Operator", " \\zs[a-zA-Z$]\\ze ")
  popup.action_highlight = vim.fn.matchadd("Operator", " \\zs<[a-zA-Z-]*>\\ze ")
  popup.key_highlight = vim.fn.matchadd("Operator", "^ \\(-\\|=\\)[a-zA-Z]")
  popup.title_highlight = vim.fn.matchadd("Function", "^[a-zA-Z]\\S*")

  for _, h in pairs(popup.highlights) do
    use_highlight(h)
  end
end

local function toggle_popup_switch(buf_handle, key)
  local popup = popups[buf_handle]
  for _, switch in pairs(popup.switches) do
    if switch.key == key then
      local h = popup.highlights["-" .. switch.key]

      switch.enabled = not switch.enabled
      h.enabled = switch.enabled

      if h.id ~= 0 then
        vim.fn.matchdelete(h.id)
      end

      use_highlight(h)
      break
    end
  end
end

local function do_action(buf_handle, key)
  local popup = popups[buf_handle]
  for _, col in pairs(popup.actions) do
    for _, item in pairs(col) do
      if item.key == key then
        local ret = item.callback(popup)
        vim.api.nvim_command(buf_handle .. "bw")
        if type(ret) == "function" then
          ret()
        end
        return
      end
    end
  end
end

local function toggle_popup_option(buf_handle, key)
  local popup = popups[buf_handle]
  for _, option in pairs(popup.options) do
    if option.key == key then
      local h = popup.highlights["=" .. option.key]

      if h.enabled then
        vim.api.nvim_win_set_cursor(0, { h.line, h.col + h.length - 1 })
        vim.api.nvim_buf_set_option(buf_handle, "modifiable", true)
        vim.api.nvim_command("norm! dt)")
        vim.api.nvim_buf_set_option(buf_handle, "modifiable", false)
      end

      option.value = vim.fn.input({
        prompt = option.cli .. "=",
        default = option.value,
        cancelreturn = option.value
      })

      h.enabled = #option.value ~= 0

      if h.enabled then
        vim.api.nvim_win_set_cursor(0, { h.line, h.col + h.length - 1 })
        vim.api.nvim_buf_set_option(buf_handle, "modifiable", true)
        vim.api.nvim_put({option.value}, "c", false, false)
        vim.api.nvim_buf_set_option(buf_handle, "modifiable", false)
      end

      if h.id ~= 0 then
        vim.fn.matchdelete(h.id)
      end

      use_highlight(h)
      break
    end
  end
end

local function toggle(buf_handle)
  local line = vim.fn.getline('.')
  local matches = vim.fn.matchlist(line, "^ \\([-=]\\)\\([a-zA-Z]\\)")
  local is_switch = matches[2] == "-"
  local key = matches[3]
  if is_switch then
    toggle_popup_switch(buf_handle, key)
  else
    toggle_popup_option(buf_handle, key)
  end
end

local function create_popup(id, switches, options, actions, env)
  local function collect_arguments()
    local flags = {}
    for _, switch in pairs(switches) do
      if switch.enabled and switch.parse ~= false then
        table.insert(flags, "--" .. switch.cli)
      end
    end
    for _, option in pairs(options) do
      if #option.value ~= 0 and option.parse ~= false then
        table.insert(flags, "--" .. option.cli .. "=" .. option.value)
      end
    end
    return flags
  end

  local popup = {
    id = id,
    switches = switches,
    options = options,
    actions = actions,
    env = env,
    to_cli = function()
      local flags = collect_arguments()
      return table.concat(flags, " ")
    end,
    get_arguments = function ()
      return collect_arguments()
    end
  }

  local buf_handle = vim.fn.bufnr(popup.id)

  if buf_handle == -1 then
    vim.api.nvim_command("below new")
    buf_handle = vim.api.nvim_get_current_buf()

    popups[buf_handle] = popup

    vim.api.nvim_command("set nonu")
    vim.api.nvim_command("set nornu")

    vim.api.nvim_buf_set_option(buf_handle, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf_handle, "bufhidden", "hide")
    vim.api.nvim_buf_set_option(buf_handle, "swapfile", false)
    vim.api.nvim_buf_set_name(buf_handle, popup.id)

    draw_popup(popup)

    vim.api.nvim_buf_set_option(buf_handle, "readonly", true)
    vim.api.nvim_buf_set_option(buf_handle, "modifiable", false)
  else
    local win_handle = vim.fn.bufwinnr(popup.id)
    if win_handle == -1 then
      vim.api.nvim_command("below new")
      vim.api.nvim_command("b" .. buf_handle)
    else
      vim.api.nvim_command(win_handle .. "wincmd w")
    end
  end

  for _, switch in pairs(switches) do
    vim.api.nvim_buf_set_keymap(
      buf_handle,
      "n",
      "-" .. switch.key,
      string.format("<cmd>lua require'neogit.lib.popup.lib'.toggle_switch(%d, '%s')<CR>", buf_handle, switch.key),
      {
        noremap = true,
        silent = true,
        nowait = true
      }
    )
  end

  for _, option in pairs(options) do
    vim.api.nvim_buf_set_keymap(
      buf_handle,
      "n",
      "=" .. option.key,
      string.format("<cmd>lua require'neogit.lib.popup.lib'.toggle_option(%d, '%s')<CR>", buf_handle, option.key),
      {
        noremap = true,
        silent = true,
        nowait = true
      }
    )
  end

  for _, col in pairs(actions) do
    for _, item in pairs(col) do
      vim.api.nvim_buf_set_keymap(
        buf_handle,
        "n",
        item.key,
        string.format("<cmd>lua require'neogit.lib.popup.lib'.do_action(%d, '%s')<CR>", buf_handle, item.key),
        {
          noremap = true,
          silent = true,
          nowait = true
        }
      )
    end
  end

  vim.api.nvim_buf_set_keymap(
    buf_handle,
    "n",
    "q",
    "<cmd>bw<CR>",
    {
      noremap = true,
      silent = true,
      nowait = true
    }
  )
  vim.api.nvim_buf_set_keymap(
    buf_handle,
    "n",
    "<TAB>",
    string.format("<cmd>lua require'neogit.lib.popup.lib'.toggle(%d)<CR>", buf_handle),
    {
      noremap = true,
      silent = true,
      nowait = true
    }
  )
end

local function new()
  local builder = {
    state = {
      name = nil,
      switches = {},
      options = {},
      actions = {{}},
      env = {}
    }
  }

  function builder.name(name)
    builder.state.name = name
    return builder
  end
 
  function builder.env(env)
    builder.state.env = env
    return builder
  end

  function builder.new_action_group()
    table.insert(builder.state.actions, {})
    return builder
  end

  function builder.switch(key, cli, description, enabled)
    if enabled == nil then
      enabled = false
    end

    table.insert(builder.state.switches, {
      key = key,
      cli = cli,
      description = description,
      enabled = enabled
    })

    return builder
  end

  function builder.option(key, cli, value, description)
    table.insert(builder.state.options, {
      key = key,
      cli = cli,
      value = value,
      description = description,
    })

    return builder
  end

  function builder.action(key, description, callback)
    table.insert(builder.state.actions[#builder.state.actions], {
      key = key,
      description = description,
      callback = callback and a.void(callback) or function() end
    })

    return builder
  end

  function builder.build()
    if builder.state.name == nil then
      error("A popup needs to have a name!")
    end

    return create_popup(
      builder.state.name,
      builder.state.switches,
      builder.state.options,
      builder.state.actions,
      builder.state.env
    )
  end

  return builder
end

return {
  create = create_popup,
  new = new,
  toggle = toggle,
  toggle_switch = toggle_popup_switch,
  toggle_option = toggle_popup_option,
  do_action = do_action
}
