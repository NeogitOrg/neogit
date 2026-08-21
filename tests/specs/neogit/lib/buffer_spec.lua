local eq = assert.are.same
local Buffer = require("neogit.lib.buffer")
local Ui = require("neogit.lib.ui")

describe("buffer decorations", function()
  local buffer
  local original_window
  local unfocused_window

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
