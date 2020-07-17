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

  vim.api.nvim_buf_set_name(buf_handle, config.name)
  vim.api.nvim_buf_set_option(buf_handle, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf_handle, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(buf_handle, "swapfile", false)

  config.initialize(buf_handle)

  vim.api.nvim_buf_set_option(buf_handle, "readonly", true)
  vim.api.nvim_buf_set_option(buf_handle, "modifiable", false)
  vim.api.nvim_buf_set_keymap(
    buf_handle,
    "n",
    "q",
    "<cmd>bw<CR>",
    {
      noremap = true,
      silent = true
    }
  )
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
