# frozen_string_literal: true

class NeovimClient # rubocop:disable Metrics/ClassLength
  def initialize
    @instance = nil
  end

  def setup(neogit_config) # rubocop:disable Metrics/MethodLength
    @instance = attach_child

    # Sets up the runtimepath
    runtime_dependencies.each do |dep|
      lua "vim.opt.runtimepath:prepend('#{dep}')"
    end

    lua "vim.opt.runtimepath:prepend('#{PROJECT_DIR}')"

    lua <<~LUA
      require("plenary")
      require('neogit').setup(#{neogit_config})
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

  def screen # rubocop:disable Metrics/MethodLength
    @instance.command("redraw")

    screen  = []
    lines   = evaluate "&lines"
    columns = evaluate "&columns"

    lines.times do |line|
      current_line = []
      columns.times do |column|
        current_line << fn("screenstring", [line + 1, column + 1])
      end

      screen << current_line.join
    end

    screen
  end

  def print_screen
    puts `clear`
    puts screen.join("\n")
  end

  def lua(code)
    @instance.exec_lua(code, [])
  end

  def fn(function, ...)
    @instance.call_function(function, ...)
  end

  def evaluate(expr)
    @instance.evaluate expr
  end

  def cmd(command)
    @instance.command_output(command).lines
  end

  def move_to_line(line, after: nil) # rubocop:disable Metrics/MethodLength
    if line.is_a? Integer
      lua "vim.api.nvim_win_set_cursor(0, {#{line}, 0})"
    elsif line.is_a? String
      preceding_found = after.nil?

      screen.each_with_index do |content, i|
        preceding_found ||= content.include?(after)
        if preceding_found && content.include?(line)
          lua "vim.api.nvim_win_set_cursor(0, {#{i}, 0})"
          break
        end
      end
    end
  end

  def errors
    messages   = cmd("messages")
    vim_errors = messages.grep(/^E\d+: /)
    lua_errors = messages.grep(/The coroutine failed with this message/)

    (vim_errors + lua_errors).map(&:strip)
  end

  def filetype
    evaluate "&filetype"
  end

  def assert_alive!
    return true if evaluate("1 + 2") == 3

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

  def confirm(state)
    lua <<~LUA
      vim.fn.confirm = function()
        return #{state ? 1 : 0}
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
