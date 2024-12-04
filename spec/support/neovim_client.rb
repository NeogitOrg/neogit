# frozen_string_literal: true

require "pastel"

class NeovimClient # rubocop:disable Metrics/ClassLength
  def initialize(mode)
    @mode     = mode
    @pid      = nil
    @instance = nil
    @cleared  = false
    @lines    = nil
    @columns  = nil
    @pastel   = Pastel.new
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
      require("diffview").setup()
      require('neogit').setup(#{neogit_config})
      require('neogit').open()
    LUA

    sleep(0.1) # Seems to be about right
    assert_alive!

    @lines = evaluate "&lines"
    @columns = evaluate "&columns"
  end

  def teardown
    if @mode == :tcp
      system("kill -9 #{@pid}")
      @pid = nil
    end

    # @instance.shutdown # Seems to hang sometimes
    @instance = nil
  end

  def refresh
    lua "require('neogit.buffers.status').instance():dispatch_refresh()"
  end

  def screen
    @instance.command("redraw")

    screen = []

    @lines.times do |line|
      current_line = []
      @columns.times do |column|
        current_line << fn("screenstring", [line + 1, column + 1])
      end

      screen << current_line.join
    end

    screen
  end

  # TODO: When the cursor is in a floating window the screenrow value returned is incorrect
  def print_screen # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    cursor_line = fn("screenrow", []) - 1
    cursor_col  = fn("screencol", []) - 1

    unless @cleared
      puts `clear`
      @cleared = true
    end

    puts "\e[H" # Sets cursor back to 0,0
    screen.each_with_index do |line, i|
      puts(
        if i == cursor_line
          line[...cursor_col] +
          @pastel.black.on_yellow(line[cursor_col]) +
          line[(cursor_col + 1..)]
        else
          line
        end
      )
    end
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
      sleep(0.1)
    end
  end

  def attach_child
    case @mode
    when :pipe then attach_pipe
    when :tcp  then attach_tcp
    end
  end

  def runtime_dependencies
    Dir[File.join(PROJECT_DIR, "tmp", "*")].select { Dir.exist? _1 }
  end

  private

  def attach_pipe
    Neovim.attach_child(["nvim", "--embed", "--clean", "--headless"])
  end

  def attach_tcp
    @pid = spawn("nvim", "--embed", "--headless", "--clean", "--listen", "localhost:9999")
    Process.detach(@pid)

    attempts = 0
    loop do
      return Neovim.attach_tcp("localhost", "9999")
    rescue Errno::ECONNREFUSED
      attempts += 1
      raise "Couldn't connect via TCP after 10 seconds" if attempts > 100

      sleep 0.1
    end
  end
end
