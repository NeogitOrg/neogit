# frozen_string_literal: true

def dir_name(name)
  name.match(/[^\/]+\/(?<dir_name>[^\.]+)/)[:dir_name]
end

def ensure_installed(name)
  tmp = File.join(PROJECT_DIR, "tmp")
  Dir.mkdir(tmp) if !Dir.exist?(tmp)

  dir = File.join(tmp, dir_name(name))

  return if Dir.exist?(dir) && !Dir.empty?(dir)

  puts "Downloading dependency #{name} to #{dir}"
  Dir.mkdir(dir)
  Git.clone("git@github.com:#{name}.git", dir)
end

ensure_installed "nvim-lua/plenary.nvim"
ensure_installed "nvim-telescope/telescope.nvim"
