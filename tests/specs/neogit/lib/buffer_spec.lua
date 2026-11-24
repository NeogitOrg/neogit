local eq = assert.are.same
local Buffer = require("neogit.lib.buffer")
local Ui = require("neogit.lib.ui")

describe("buffer decorations", function()
  local buffer
  local original_window
  local unfocused_window
  local replacement_buffer

  local function extmarks(namespace)
    return vim.api.nvim_buf_get_extmarks(buffer.handle, buffer:get_namespace_id(namespace), 0, -1, {})
  end

  before_each(function()
    original_window = vim.api.nvim_get_current_win()
  end)

  after_each(function()
    if original_window and vim.api.nvim_win_is_valid(original_window) then
      vim.api.nvim_set_current_win(original_window)
    end

    if unfocused_window and vim.api.nvim_win_is_valid(unfocused_window) then
      vim.api.nvim_win_close(unfocused_window, true)
    end

    if buffer then
      buffer:set_decorations("ActiveItem", {})
      if vim.api.nvim_buf_is_valid(buffer.handle) then
        vim.api.nvim_buf_delete(buffer.handle, { force = true })
      end
    end

    if replacement_buffer and vim.api.nvim_buf_is_valid(replacement_buffer) then
      vim.api.nvim_buf_delete(replacement_buffer, { force = true })
    end
  end)

  it("does not accumulate active item highlights while unfocused", function()
    local active_item = { oid = require("neogit.buffers.commit_view").current_oid() }
    buffer = Buffer.create {
      name = "NeogitActiveItemHighlightTest",
      kind = "split",
      bufhidden = "hide",
      active_item_highlight = true,
      render = function()
        return {
          Ui.row({ Ui.text("active item") }, { item = active_item }),
        }
      end,
    }

    vim.cmd.vnew()
    unfocused_window = vim.api.nvim_get_current_win()
    for _ = 1, 3 do
      vim.cmd("redraw!")

      local marks = extmarks("ActiveItem")
      eq(1, #marks)
      eq({ 0, 0 }, { marks[1][2], marks[1][3] })
    end
  end)

  it("only decorates its owning buffer", function()
    local active_item = { oid = require("neogit.buffers.commit_view").current_oid() }
    buffer = Buffer.create {
      name = "NeogitActiveItemOwnerTest",
      kind = "split",
      bufhidden = "hide",
      active_item_highlight = true,
      render = function()
        return {
          Ui.row({ Ui.text("active item") }, { item = active_item }),
        }
      end,
    }

    replacement_buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(buffer.win_handle, replacement_buffer)
    buffer:clear_namespace("ActiveItem")
    vim.cmd("redraw!")

    eq(0, #extmarks("ActiveItem"))
  end)

  it("clears a namespace while another buffer is focused", function()
    buffer = Buffer.create {
      name = "NeogitUnfocusedNamespaceClearTest",
      kind = "split",
      bufhidden = "hide",
      render = function()
        return { Ui.text("highlighted line") }
      end,
    }
    buffer:create_namespace("Test")
    buffer:add_line_highlight(0, "NeogitActiveItem", { namespace = "Test" })

    vim.api.nvim_set_current_win(original_window)
    assert.is_false(buffer:is_focused())
    buffer:clear_namespace("Test")

    eq(0, #extmarks("Test"))
  end)
end)

describe("buffer filetype and window options", function()
  local buffers
  local original_window
  local original_wrap
  local original_rtp
  local original_eventignore
  local temp_dirs
  local augroups

  local function create_buffer(opts)
    local buf = Buffer.create(opts)
    table.insert(buffers, buf)
    return buf
  end

  before_each(function()
    buffers = {}
    temp_dirs = {}
    augroups = {}
    original_window = vim.api.nvim_get_current_win()
    original_wrap = vim.o.wrap
    original_rtp = vim.o.runtimepath
    original_eventignore = vim.o.eventignore
  end)

  after_each(function()
    vim.o.wrap = original_wrap
    vim.o.runtimepath = original_rtp
    vim.o.eventignore = original_eventignore

    for _, group in ipairs(augroups) do
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end

    if original_window and vim.api.nvim_win_is_valid(original_window) then
      vim.api.nvim_set_current_win(original_window)
    end

    for _, buf in ipairs(buffers) do
      if
        buf.win_handle
        and buf.win_handle ~= original_window
        and vim.api.nvim_win_is_valid(buf.win_handle)
      then
        pcall(vim.api.nvim_win_close, buf.win_handle, true)
      end
      if buf.handle and vim.api.nvim_buf_is_valid(buf.handle) then
        pcall(vim.api.nvim_buf_delete, buf.handle, { force = true })
      end
    end

    for _, dir in ipairs(temp_dirs) do
      vim.fn.delete(dir, "rf")
    end
  end)

  it("keeps wrap disabled by default on gitcommit and NeogitStatus buffers", function()
    vim.o.wrap = true

    local commit_buf = create_buffer {
      name = vim.fn.tempname() .. "/COMMIT_EDITMSG",
      filetype = "gitcommit",
      buftype = "",
      kind = "split",
      bufhidden = "wipe",
    }
    eq(false, vim.api.nvim_get_option_value("wrap", { win = commit_buf.win_handle }))

    local status_buf = create_buffer {
      name = "NeogitStatusWrapDefaultTest",
      filetype = "NeogitStatus",
      kind = "split",
      bufhidden = "wipe",
    }
    eq(false, vim.api.nvim_get_option_value("wrap", { win = status_buf.win_handle }))
  end)

  it("allows after/ftplugin/gitcommit.lua to enable wrap even when global wrap is false", function()
    vim.o.wrap = false

    local temp_dir = vim.fn.tempname()
    table.insert(temp_dirs, temp_dir)
    local after_dir = temp_dir .. "/after"
    vim.fn.mkdir(after_dir .. "/ftplugin", "p")
    vim.fn.writefile({ "vim.opt_local.wrap = true" }, after_dir .. "/ftplugin/gitcommit.lua")
    vim.opt.runtimepath:append(after_dir)

    local buffer = create_buffer {
      name = temp_dir .. "/COMMIT_EDITMSG",
      filetype = "gitcommit",
      buftype = "",
      kind = "split",
      bufhidden = "wipe",
    }

    eq(true, vim.api.nvim_get_option_value("wrap", { win = buffer.win_handle }))
    eq(1, vim.b[buffer.handle].did_ftplugin)
    eq(original_eventignore, vim.o.eventignore)
  end)

  it("allows FileType autocmds to override default wrap and spell options", function()
    local group = vim.api.nvim_create_augroup("NeogitBufferFileTypeOverrideTest", { clear = true })
    table.insert(augroups, group)

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "gitcommit",
      callback = function()
        vim.opt_local.wrap = true
        vim.opt_local.spell = false
      end,
    })

    local buffer = create_buffer {
      name = vim.fn.tempname() .. "/COMMIT_EDITMSG",
      filetype = "gitcommit",
      buftype = "",
      spell_check = true,
      kind = "split",
      bufhidden = "wipe",
    }

    eq(true, vim.api.nvim_get_option_value("wrap", { win = buffer.win_handle }))
    eq(false, vim.api.nvim_get_option_value("spell", { win = buffer.win_handle }))
  end)

  it("handles windows closed during initialize and open = false buffers safely", function()
    local closed_buf = create_buffer {
      name = vim.fn.tempname() .. "/COMMIT_EDITMSG_CLOSED",
      filetype = "gitcommit",
      buftype = "",
      kind = "split",
      bufhidden = "hide",
      initialize = function(_, win)
        vim.api.nvim_win_close(win, true)
      end,
    }

    eq("gitcommit", vim.bo[closed_buf.handle].filetype)
    eq(original_eventignore, vim.o.eventignore)

    local hidden_buf = create_buffer {
      name = "NeogitHiddenFileTypeTest",
      filetype = "NeogitConsole",
      open = false,
      bufhidden = "wipe",
    }

    eq("NeogitConsole", vim.bo[hidden_buf.handle].filetype)
    eq(nil, hidden_buf.win_handle)
    eq(original_eventignore, vim.o.eventignore)
  end)
end)
