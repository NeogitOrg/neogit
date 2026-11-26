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

describe("Buffer.from_name", function()
  local original_cwd
  local handles = {}

  before_each(function()
    original_cwd = vim.fn.getcwd()
  end)

  after_each(function()
    vim.cmd.cd(vim.fn.fnameescape(original_cwd))
    for _, handle in ipairs(handles) do
      if vim.api.nvim_buf_is_valid(handle) then
        vim.api.nvim_buf_delete(handle, { force = true })
      end
    end
    handles = {}
  end)

  local function from_name_in(dir, name)
    vim.cmd.cd(vim.fn.fnameescape(dir))
    local buffer = Buffer.from_name(name)
    table.insert(handles, buffer.handle)
    return buffer
  end

  it("does not reuse a buffer with the same name from another directory", function()
    local first_dir = vim.fn.tempname()
    local second_dir = vim.fn.tempname()
    vim.fn.mkdir(first_dir, "p")
    vim.fn.mkdir(second_dir, "p")

    local first = from_name_in(first_dir, "NeogitFromNameTest")
    local second = from_name_in(second_dir, "NeogitFromNameTest")

    assert.are_not.equal(first.handle, second.handle)
    eq(first.handle, from_name_in(first_dir, "NeogitFromNameTest").handle)
    eq(second.handle, from_name_in(second_dir, "NeogitFromNameTest").handle)
  end)
end)

describe("kept hidden buffers", function()
  local original_window
  local other_window
  local file_buf
  local buffer

  before_each(function()
    original_window = vim.api.nvim_get_current_win()
    file_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(original_window, file_buf)
  end)

  after_each(function()
    if original_window and vim.api.nvim_win_is_valid(original_window) then
      vim.api.nvim_set_current_win(original_window)
      if vim.api.nvim_buf_is_valid(file_buf) then
        vim.api.nvim_win_set_buf(original_window, file_buf)
      end
    end

    if other_window and vim.api.nvim_win_is_valid(other_window) then
      vim.api.nvim_win_close(other_window, true)
    end
    other_window = nil

    if buffer and vim.api.nvim_buf_is_valid(buffer.handle) then
      vim.api.nvim_buf_delete(buffer.handle, { force = true })
    end
    buffer = nil

    if file_buf and vim.api.nvim_buf_is_valid(file_buf) then
      vim.api.nvim_buf_delete(file_buf, { force = true })
    end
  end)

  it(
    "keeps hidden buffers listed, updates win_handle on re-show in another window, and preserves window options",
    function()
      local enter_wins = {}
      local leave_count = 0

      buffer = Buffer.create {
        name = "NeogitKeptHiddenTest",
        kind = "replace",
        bufhidden = "hide",
        buflisted = true,
        header = "Test Header",
        disable_line_numbers = true,
        disable_relative_line_numbers = true,
        on_win_enter = function(_, win)
          table.insert(enter_wins, win)
        end,
        on_win_leave = function()
          leave_count = leave_count + 1
        end,
        render = function()
          return { Ui.text("line 1"), Ui.text("line 2") }
        end,
      }

      assert.is_true(vim.api.nvim_get_option_value("buflisted", { buf = buffer.handle }))
      eq("hide", vim.api.nvim_get_option_value("bufhidden", { buf = buffer.handle }))
      eq(original_window, buffer:get_win_handle())

      -- Close back to file_buf: buffer must stay alive & listed, and header must close
      buffer:close()
      assert.is_true(vim.api.nvim_buf_is_valid(buffer.handle))
      assert.is_true(vim.api.nvim_get_option_value("buflisted", { buf = buffer.handle }))
      eq(file_buf, vim.api.nvim_win_get_buf(original_window))
      eq(1, leave_count)
      eq(nil, buffer:get_win_handle())

      -- Mutating window options while hidden must NOT affect original_window (showing file_buf)
      vim.api.nvim_set_option_value("number", true, { win = original_window })
      buffer:set_window_option("number", false)
      assert.is_true(vim.api.nvim_get_option_value("number", { win = original_window }))

      -- Show the kept buffer in a completely different split window with pre-existing options
      vim.cmd.vnew()
      other_window = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value("number", true, { win = other_window })
      vim.api.nvim_set_option_value("wrap", true, { win = other_window })
      vim.api.nvim_win_set_buf(other_window, buffer.handle)

      eq(other_window, buffer:get_win_handle())
      eq(other_window, enter_wins[#enter_wins])
      eq("manual", vim.api.nvim_get_option_value("foldmethod", { win = other_window }))
      assert.is_false(vim.api.nvim_get_option_value("number", { win = other_window }))
      assert.is_false(vim.api.nvim_get_option_value("wrap", { win = other_window }))

      -- Re-creating the header on BufWinEnter must not duplicate header virtual lines
      local header_ns = buffer:get_namespace_id("Header")
      local header_marks = vim.api.nvim_buf_get_extmarks(buffer.handle, header_ns, 0, -1, {})
      eq(1, #header_marks)

      -- Closing from other_window restores alternate/old buffer cleanly
      buffer:close()
      assert.is_true(vim.api.nvim_buf_is_valid(buffer.handle))
      assert.are_not.equal(buffer.handle, vim.api.nvim_win_get_buf(other_window))
    end
  )
end)
