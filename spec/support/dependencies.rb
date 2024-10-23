# frozen_string_literal: true

def dir_name(name)
  name.match(%r{[^/]+/(?<dir_name>[^\.]+)})[:dir_name]
end

def ensure_installed(name, build: nil)
  tmp = File.join(PROJECT_DIR, "tmp")
  FileUtils.mkdir_p(tmp)

  dir = File.join(tmp, dir_name(name))

  return if Dir.exist?(dir) && !Dir.empty?(dir)

  puts "Downloading dependency #{name} to #{dir}"
  Dir.mkdir(dir)
  Git.clone("git@github.com:#{name}.git", dir, filter: "tree:0")
  return unless build.present?

  puts "Building #{name} via #{build}"
  Dir.chdir(dir) { system(build) }
end

ensure_installed "nvim-lua/plenary.nvim"
ensure_installed "nvim-telescope/telescope.nvim"
ensure_installed "nvim-telescope/telescope-fzf-native.nvim", build: "make"
ensure_installed "sindrets/diffview.nvim"
