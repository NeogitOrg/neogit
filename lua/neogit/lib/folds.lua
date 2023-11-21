local M = {}

function M.fold_text()
  local text = vim.fn.getline(vim.v.foldstart)

  if not vim.fn.has("nvim-0.10") == 1 then
    return text
  end

  local bufnr = vim.fn.bufnr()
  local ns = vim.api.nvim_get_namespaces()["neogit-buffer-" .. bufnr]

  local lnum = vim.v.foldstart - 1
  local start_range = { lnum, 0 }
  local end_range = { lnum, -1 }

  local last_col_end = 0
  local res = {}

  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, start_range, end_range, { details = true })

  for _, m in ipairs(marks) do
    local start_col, details = m[3], m[4]
    local end_col = details.end_col or (start_col + 1)
    local hl_group = details.hl_group

    if hl_group then
      if start_col > last_col_end then
        table.insert(res, { text:sub(last_col_end + 1, start_col), "NeogitGraphWhite" })
      end

      last_col_end = end_col
      table.insert(res, { text:sub(start_col + 1, end_col), hl_group })
    end
  end

  if #text > last_col_end then
    table.insert(res, { text:sub(last_col_end + 1, -1), "NeogitGraphWhite" })
  end

  return res
end

function M.setup()
  _G.NeogitBufferFoldText = M.fold_text
end

return M
