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
---@return string The path to the project directory
function M.get_test_files_dir()
  return M.project_dir .. "/tests/test_files/"
end

---Runs a system command and errors if it fails
---@param cmd string Command to be ran
---@param ignore_err boolean? Whether the error should be ignored
---@param error_msg string? The error message to be emitted on command failure
---@return string The output of the system command
function M.system(cmd, ignore_err, error_msg)
  if ignore_err ~= nil then
    ignore_err = false
  end

  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 and not ignore_err then
    error(error_msg or ("Command failed: ↓\n" .. cmd .. "\nOutput from command: ↓\n" .. output))
  end
  return output
end

return M
