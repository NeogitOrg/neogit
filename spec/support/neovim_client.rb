# frozen_string_literal: true

class NeovimClient
  def initialize
    @instance = nil
  end

  def setup
    @instance = attach_child

    if ENV["CI"]
      lua <<~LUA
        vim.cmd.runtime("plugin/plenary.vim")
        vim.cmd.runtime("plugin/neogit.lua")
      LUA
    else
      # Sets up the runtimepath
      runtime_dependencies.each do |dep|
        lua "vim.opt.runtimepath:prepend('#{dep}')"
      end
    end

    lua "vim.opt.runtimepath:prepend('#{PROJECT_DIR}')"

    lua <<~LUA
      require("plenary")
      require('neogit').setup()
      require('neogit').open()
    LUA

    sleep(0.025) # Seems to be about right
  end

  def teardown
    @instance.shutdown
    @instance = nil
  end

  def print_screen
    puts get_lines
  end

  def lua(code)
    @instance.exec_lua(code, [])
  end

  def get_lines
    @instance.current.buffer.get_lines(0, -1, true).join("\n")
  end

  # Overload vim.fn.input() to prevent blocking.
  def input(*args)
    lua <<~LUA
      local inputs = { #{args.map(&:inspect).join(",")} }

      vim.fn.input = function()
        return table.remove(inputs, 1)
      end
    LUA
  end

  # Higher-level user input
  def feedkeys(keys, mode: 'm')
    @instance.feedkeys(
      @instance.replace_termcodes(keys, true, false, true),
      mode,
      false
    )
  end

  def attach_child
    if ENV["CI"]
      Neovim.attach_child(["nvim", "--embed", "--headless"])
  else
      Neovim.attach_child(["nvim", "--embed", "--clean", "--headless"])
    end
  end

  def runtime_dependencies
    Dir[File.join(PROJECT_DIR, "tmp", "*")].select { Dir.exist? _1 }
  end
end
