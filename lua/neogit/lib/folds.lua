-- For Nightly, a function that constructs the fold text
local M = {}

function M.fold_text()
  local text = vim.fn.getline(vim.v.foldstart)
  local bufnr = vim.fn.bufnr()
  local ns = vim.api.nvim_get_namespaces()["neogit-buffer-" .. bufnr]

  local lnum = vim.v.foldstart - 1
  local startRange = { lnum, 0 }
  local endRange = { lnum, -1 }

  local lastColEnd = 0
  local hlRes = {}
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, startRange, endRange, { details = true })
  for i, m in ipairs(marks) do
    local sc, details = m[3], m[4]
    local ec = details.end_col or (sc + 1)
    local hlGroup = details.hl_group

    if hlGroup then
      if sc > lastColEnd then
        table.insert(hlRes, { text:sub(lastColEnd + 1, sc), "NeogitGraphWhite" })
      end

      if i == 1 then
        table.insert(hlRes, { text:sub(sc + 1, ec + 1), hlGroup })
        lastColEnd = ec + 1
      else
        table.insert(hlRes, { text:sub(sc + 1, ec), hlGroup })
        lastColEnd = ec
      end
    end
  end

  if #text > lastColEnd then
    table.insert(hlRes, { text:sub(lastColEnd + 1, -1), "NeogitGraphWhite" })
  end

  return hlRes
end

function M.setup()
  _G.NeogitBufferFoldText = M.fold_text
end

return M
