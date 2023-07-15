local M = {}

M.project_dir = vim.fn.getcwd()

---Checks if both lists contain the same values. This does NOT check ordering.
---@param l1 any[]
---@param l2 any[]
---@return boolean
function M.lists_equal(l1, l2)
  if #l1 ~= #l2 then
    return false
  end

  for _, value in ipairs(l1) do
    if not vim.tbl_contains(l2, value) then
      return false
    end
  end

  return true
end

---Removes the given value from the table
---@param tbl table
---@param value any
function M.remove_item_from_table(tbl, value)
  for index, t_value in ipairs(tbl) do
    if vim.deep_equal(t_value, value) then
      table.remove(tbl, index)
    end
  end
end

---Returns the path to the raw test files directory
---@return string
function M.get_test_files_dir()
  return M.project_dir .. "/tests/test_files/"
end

return M
