local M = {}

-- TODO: All callers of nvim_exec_autocmd should route through here

---@param name string
---@param data table?
function M.send(name, data)
  assert(name, "event must have name")

  vim.api.nvim_exec_autocmds("User", {
    pattern = "Neogit" .. name,
    modeline = false,
    data = data,
  })
end

return M
