# frozen_string_literal: true

class NeovimClient
  def initialize
    @instance = nil
  end

  def setup # rubocop:disable Metrics/MethodLength
    @instance = attach_child

    # Sets up the runtimepath
    runtime_dependencies.each do |dep|
      lua "vim.opt.runtimepath:prepend('#{dep}')"
    end

    lua "vim.opt.runtimepath:prepend('#{PROJECT_DIR}')"

    lua <<~LUA
      require("plenary")
      require('neogit').setup()
      require('neogit').open()
    LUA

    sleep(0.1) # Seems to be about right
    assert_alive!
  end

  def teardown
    # @instance.shutdown # Seems to hang sometimes
    @instance = nil
  end

  def refresh
    lua "require('neogit.buffers.status').instance():dispatch_refresh()"
  end

  def print_screen # rubocop:disable Metrics/MethodLength
    @instance.command("redraw")

    screen  = []
    lines   = @instance.evaluate("&lines")
    columns = @instance.evaluate("&columns")

    lines.times do |line|
      current_line = []
      columns.times do |column|
        current_line << @instance.call_function("screenstring", [line + 1, column + 1])
      end

      screen << current_line.join
    end

    puts `clear`
    puts screen.join("\n")
  end

  def lua(code)
    @instance.exec_lua(code, [])
  end

  def assert_alive!
    return true if @instance.evaluate("1 + 2") == 3

    raise "Neovim instance is not alive!"
  end

  # Overload vim.fn.input() to prevent blocking.
  def input(*args)
    lua <<~LUA
      local inputs = { #{args.map(&:inspect).join(',')} }

      vim.fn.input = function()
        return table.remove(inputs, 1)
      end
    LUA
  end

  def keys(keys) # rubocop:disable Metrics/MethodLength
    keys = keys.chars

    until keys.empty?
      key = keys.shift
      key += keys.shift until key.last == ">" if key == "<"

      if @instance.input(key).nil?
        assert_alive!
        raise "Failed to write key to neovim: #{key.inspect}"
      end

      print_screen unless ENV["CI"]
      sleep(0.05)
    end
  end

  def attach_child
    Neovim.attach_child(["nvim", "--embed", "--clean", "--headless"])
  end

  def runtime_dependencies
    Dir[File.join(PROJECT_DIR, "tmp", "*")].select { Dir.exist? _1 }
  end
end
