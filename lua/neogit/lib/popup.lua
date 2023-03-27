local PopupBuilder = require("neogit.lib.popup.builder")
local Buffer = require("neogit.lib.buffer")
local common = require("neogit.buffers.common")
local Ui = require("neogit.lib.ui")
local logger = require("neogit.logger")
local util = require("neogit.lib.util")
local config = require("neogit.config")
local state = require("neogit.lib.state")
local branch = require("neogit.lib.git.branch")

local col = Ui.col
local row = Ui.row
local text = Ui.text
local Component = Ui.Component
local map = util.map
local filter_map = util.filter_map
local build_reverse_lookup = util.build_reverse_lookup
local intersperse = util.intersperse
local List = common.List
local Grid = common.Grid

local M = {}

function M.builder()
  return PopupBuilder.new(M.new)
end

function M.new(state)
  local instance = {
    state = state,
    buffer = nil,
  }
  setmetatable(instance, { __index = M })
  return instance
end

---@return string[]
function M:get_arguments()
  local flags = {}
  for _, switch in pairs(self.state.switches) do
    if switch.enabled and switch.parse ~= false then
      if #switch.cli == 1 then
        table.insert(flags, "-" .. switch.cli)
      else
        table.insert(flags, "--" .. switch.cli)
      end
    end
  end
  for _, option in pairs(self.state.options) do
    if #option.value ~= 0 and option.parse ~= false then
      table.insert(flags, "--" .. option.cli .. "=" .. option.value)
    end
  end
  return flags
end

function M:get_parse_arguments()
  local switches = {}
  for _, switch in pairs(self.state.switches) do
    if switch.enabled and switch.parse then
      switches[switch.cli] = switch.enabled
    end
  end
  return switches
end

function M:to_cli()
  return table.concat(self:get_arguments(), " ")
end

function M:close()
  self.buffer:close()
  self.buffer = nil
end

local function get_highlight_for_switch(switch)
  if switch.enabled then
    return "NeogitPopupSwitchEnabled"
  end

  return "NeogitPopupSwitchDisabled"
end

local function get_highlight_for_option(option)
  if option.value ~= nil and option.value ~= "" then
    return "NeogitPopupOptionEnabled"
  end

  return "NeogitPopupOptionDisabled"
end

local function get_highlight_for_config(config)
  if config.value and config.value ~= "" and config.value ~= "unset" then
    return config.type or "NeogitPopupConfigEnabled"
  end

  return "NeogitPopupConfigDisabled"
end

local function construct_config_options(config)
  local options = filter_map(config.options, function(option)
    if option == "" then
      return nil
    end

    local highlight
    if config.value == option then
      highlight = "NeogitPopupConfigEnabled"
    else
      highlight = "NeogitPopupConfigDisabled"
    end

    return text.highlight(highlight)(option)
  end)

  local value = intersperse(options, text.highlight("NeogitPopupConfigDisabled")("|"))
  table.insert(value, 1, text.highlight("NeogitPopupConfigDisabled")("["))
  table.insert(value, #value + 1, text.highlight("NeogitPopupConfigDisabled")("]"))

  return value
end

function M:toggle_switch(switch)
  switch.enabled = not switch.enabled
  local c = self.buffer.ui:find_component(function(c)
    return c.options.id == switch.id
  end)
  c.options.highlight = get_highlight_for_switch(switch)
  state.set({ self.state.name, switch.cli }, switch.enabled)
  self.buffer.ui:update()
end

function M:set_option(option)
  option.value = vim.fn.input {
    prompt = option.cli .. "=",
    default = option.value,
    cancelreturn = option.value,
  }
  local c = self.buffer.ui:find_component(function(c)
    return c.options.id == option.id
  end)
  c.options.highlight = get_highlight_for_option(option)
  c.children[#c.children].value = option.value
  state.set({ self.state.name, option.cli }, option.value)
  self.buffer.ui:update()
end

function M:set_config(config)
  local c = self.buffer.ui:find_component(function(c)
    return c.options.id == config.id
  end)

  if config.options then
    local options = build_reverse_lookup(config.options)
    local index = options[config.value]
    config.value = options[(index + 1)] or options[1]

    -- TODO: Set value via CLI

    local value_text = construct_config_options(config)

    -- Remove last n children from row
    for _, _ in ipairs(value_text) do
      table.remove(c.children)
    end

    -- insert new items to row
    for _, text in ipairs(value_text) do
      table.insert(c.children, text)
    end
  else
    local result = vim.fn.input {
      prompt = config.name .. " > ",
      default = config.value == "unset" and "" or config.value,
      cancelreturn = config.value,
    }

    config.value = result == "" and "unset" or result

    c.options.highlight = get_highlight_for_config(config)
    c.children[#c.children].value = config.value
  end

  self.buffer.ui:update()
end

local Switches = Component.new(function(props)
  return col {
    text.highlight("NeogitPopupSectionTitle")("Switches"),
    col(map(props.state, function(switch)
      return row.tag("Switch").value(switch) {
        row.highlight("NeogitPopupSwitchKey") {
          text(" -"),
          text(switch.key),
        },
        text(" "),
        text(switch.description),
        text(" ("),
        row.id(switch.id).highlight(get_highlight_for_switch(switch)) {
          text(#switch.cli == 1 and "-" or "--"),
          text(switch.cli),
        },
        text(")"),
      }
    end)),
  }
end)

local Options = Component.new(function(props)
  return col {
    text.highlight("NeogitPopupSectionTitle")("Options"),
    col(map(props.state, function(option)
      return row.tag("Option").value(option) {
        row.highlight("NeogitPopupOptionKey") {
          text(" ="),
          text(option.key),
        },
        text(" "),
        text(option.description),
        text(" ("),
        row.id(option.id).highlight(get_highlight_for_option(option)) {
          text("--"),
          text(option.cli),
          text("="),
          text(option.value or ""),
        },
        text(")"),
      }
    end)),
  }
end)

local Config = Component.new(function(props)
  return col {
    text.highlight("NeogitPopupSectionTitle")("Configuration"),
    col(map(props.state, function(config)
      local value
      if config.options then
        value = construct_config_options(config)
      else
        local value_text
        if not config.value or config.value == "" then
          value_text = "unset"
        else
          value_text = config.value
        end

        value = { text.highlight(get_highlight_for_config(config))(value_text) }
      end

      return row.tag("Config").value(config) {
        text(" "),
        row.highlight("NeogitPopupConfigKey") {
          text(config.key),
        },
        text(" " .. config.name .. " "),
        row.id(config.id) { unpack(value) },
      }
    end)),
  }
end)

local Actions = Component.new(function(props)
  return col {
    Grid.padding_left(1) {
      items = props.state,
      gap = 3,
      render_item = function(item)
        if item.heading then
          return row.highlight("NeogitPopupSectionTitle") { text(item.heading) }
        elseif not item.callback then
          return row.highlight("NeogitPopupActionDisabled") {
            text(item.key),
            text(" "),
            text(item.description),
          }
        else
          return row {
            text.highlight("NeogitPopupActionKey")(item.key),
            text(" "),
            text(item.description),
          }
        end
      end,
    },
  }
end)

function M:show()
  local mappings = {
    n = {
      ["q"] = function()
        self:close()
      end,
      ["<esc>"] = function()
        self:close()
      end,
      ["<tab>"] = function()
        local stack = self.buffer.ui:get_component_stack_under_cursor()

        for _, x in ipairs(stack) do
          if x.options.tag == "Switch" then
            self:toggle_switch(x.options.value)
            break
          elseif x.options.tag == "Config" then
            self:set_config(x.options.value)
            break
          elseif x.options.tag == "Option" then
            self:set_option(x.options.value)
            break
          end
        end
      end,
    },
  }

  for _, switch in pairs(self.state.switches) do
    mappings.n[switch.id] = function()
      self:toggle_switch(switch)
    end
  end

  for _, option in pairs(self.state.options) do
    mappings.n[option.id] = function()
      self:set_option(option)
    end
  end

  for _, config in pairs(self.state.config) do
    mappings.n[config.id] = function()
      self:set_config(config)
    end
  end

  for _, group in pairs(self.state.actions) do
    for _, action in pairs(group) do
      if action.heading then
        -- nothing
      elseif action.callback then
        mappings.n[action.key] = function()
          logger.debug(string.format("[POPUP]: Invoking action '%s' of %s", action.key, self.state.name))
          local ret = action.callback(self)
          self:close()
          if type(ret) == "function" then
            ret()
          end
        end
      else
        mappings.n[action.key] = function()
          local notif = require("neogit.lib.notification")
          notif.create(action.description .. " has not been implemented yet", vim.log.levels.WARN)
        end
      end
    end
  end

  local items = {}

  if self.state.config[1] then
    table.insert(items, Config { state = self.state.config })
  end

  if self.state.switches[1] then
    table.insert(items, Switches { state = self.state.switches })
  end

  if self.state.options[1] then
    table.insert(items, Options { state = self.state.options })
  end

  if self.state.actions[1] then
    table.insert(items, Actions { state = self.state.actions })
  end

  self.buffer = Buffer.create {
    name = self.state.name,
    filetype = "NeogitPopup",
    kind = config.values.popup.kind,
    mappings = mappings,
    after = function(buffer)
      vim.api.nvim_buf_call(buffer.handle, function()
        vim.cmd([[setlocal nocursorline]])
        vim.fn.matchadd("NeogitPopupBranchName", branch.current(), 100)
      end)

      if config.values.popup.kind == "split" then
        vim.api.nvim_buf_call(buffer.handle, function()
          vim.cmd([[execute "resize" . (line("$") + 1)]])
        end)
      end
    end,
    render = function()
      return {
        List {
          separator = "",
          items = items,
        },
      }
    end,
  }
end

return M
