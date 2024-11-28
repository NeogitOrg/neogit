local M = {}

M.project_dir = vim.fn.getcwd()

---Returns the path to the raw test files directory
---@return string The path to the project directory
function M.get_fixtures_dir()
  return vim.fn.getcwd() .. "/tests/fixtures/"
end

---Runs a system command and errors if it fails
---@param cmd string[] Command to be ran
---@param ignore_err boolean? Whether the error should be ignored
---@param error_msg string? The error message to be emitted on command failure
---@return string The output of the system command
function M.system(cmd, ignore_err, error_msg)
  if ignore_err == nil then
    ignore_err = false
  end

  local result = vim.system(cmd, { text = true }):wait()
  if result.code > 0 and not ignore_err then
    error(
      error_msg
        or (
          "Command failed: ↓\n"
          .. table.concat(cmd, " ")
          .. "\nOutput from command: ↓\n"
          .. result.stdout
          .. "\n"
          .. result.stderr
        )
    )
  end

  return result.stdout
end

M.neogit_test_base_dir = "/tmp/neogit-testing/"

local function is_macos()
  return vim.uv.os_uname().sysname == "Darwin"
end

local function is_gnu_mktemp()
  vim.fn.system { "bash", "-c", "mktemp --version | grep GNU" }
  return vim.v.shell_error == 0
end

---Create a temporary directory for use
---@param suffix string? The suffix to be appended to the temp directory, ideally avoid spaces in your suffix
---@return string The path to the temporary directory
function M.create_temp_dir(suffix)
  suffix = "neogit-" .. (suffix or "")

  local cmd
  if is_gnu_mktemp() then
    cmd = string.format("mktemp -d --suffix=%s", suffix)
  else
    -- assumes BSD mktemp for macos
    cmd = string.format("mktemp -d -t %s", suffix)
  end

  local prefix = is_macos() and "/private" or ""
  return prefix .. vim.trim(M.system(vim.split(cmd, " ")))
end

function M.ensure_installed(repo, path)
  local name = repo:match(".+/(.+)$")

  local install_path = path .. name

  vim.opt.runtimepath:prepend(install_path)

  if not vim.uv.fs_stat(install_path) then
    print("* Downloading " .. name .. " to '" .. install_path .. "/'")
    vim.fn.system { "git", "clone", "--depth=1", "git@github.com:" .. repo .. ".git", install_path }

    if vim.v.shell_error > 0 then
      error(
        string.format("! Failed to clone plugin: '%s' in '%s'!", name, install_path),
        vim.log.levels.ERROR
      )
    end
  end

  print(vim.fn.system("ls " .. install_path))
end

return M
