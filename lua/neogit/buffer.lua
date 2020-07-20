package.loaded['neogit.buffer'] = nil

local function modify(f)
  local buf_handle = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_option(buf_handle, "readonly", false)
  vim.api.nvim_buf_set_option(buf_handle, "modifiable", true)
  f()
  vim.api.nvim_buf_set_option(buf_handle, "readonly", true)
  vim.api.nvim_buf_set_option(buf_handle, "modifiable", false)
end

local function create(config)
  if config.tab then
    vim.api.nvim_command("tabnew")
  else
    vim.api.nvim_command("below new")
  end

  local buf_handle = vim.api.nvim_get_current_buf()

  vim.api.nvim_command("set nonu")
  vim.api.nvim_command("set nornu")

  vim.api.nvim_buf_set_name(buf_handle, config.name)

  vim.api.nvim_buf_set_option(buf_handle, "bufhidden", config.bufhidden or "wipe")
  vim.api.nvim_buf_set_option(buf_handle, "buftype", config.buftype or "nofile")
  vim.api.nvim_buf_set_option(buf_handle, "swapfile", false)

  config.initialize(buf_handle)

  if config.filetype then
    vim.api.nvim_command("set filetype=" .. config.filetype)
  end

  if not config.modifiable then
    vim.api.nvim_buf_set_option(buf_handle, "modifiable", false)
  end

  if config.readonly ~= nil and config.readonly then
    vim.api.nvim_buf_set_option(buf_handle, "readonly", true)
  end

  local close_cmd

  if config.tab then
    vim.api.nvim_buf_set_keymap(
      buf_handle,
      "n",
      "q",
      "<cmd>tabclose<CR>",
      {
        noremap = true,
        silent = true
      }
    )
  else
    vim.api.nvim_buf_set_keymap(
      buf_handle,
      "n",
      "q",
      "<cmd>q<CR>",
      {
        noremap = true,
        silent = true
      }
    )
  end
end

local function exists(name)
  return vim.fn.bufnr(name) ~= -1
end

local function go_to(name)
  vim.api.nvim_command(vim.fn.bufwinnr(name) .. "wincmd w")
end

return {
  create = create,
  modify = modify,
  exists = exists,
  go_to = go_to
}
