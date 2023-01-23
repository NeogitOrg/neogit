local eq = assert.are.same

describe("proof of concept", function()
  it("should work", function()
    assert(true)
  end)

  it("should have access to vim global", function()
    assert.is_not_nil(vim)
  end)

  it("should be able to interact with vim", function()
    vim.cmd("let g:val = v:true")
    eq(true, vim.g.val)
  end)

  it("has access to buffers", function()
    vim.cmd("Neogit")
    -- 1 is the neogit buffer just opened
    -- 2 The hidden console buffer
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(b)
      local ft = vim.api.nvim_buf_get_option(b, "filetype")
      local buftype = vim.api.nvim_buf_get_option(b, "buftype")
    end
    eq({ 1, 2 }, vim.api.nvim_list_bufs())
  end)
end)
