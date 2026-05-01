-- selene: allow(incorrect_standard_library_use)
local sep = package.config:sub(1, 1)

---@class NeogitPath
---@field _path string
local Path = {}
Path.__index = Path

Path.path = { sep = sep }

---@param ... string|NeogitPath One or more path segments to join
---@return NeogitPath
local function new(...)
  local args = { ... }

  -- Support both Path:new() (colon — passes Path table as first arg) and Path.new() (dot)
  if args[1] == Path then
    table.remove(args, 1)
  end

  local path
  if #args == 0 then
    path = "."
  elseif #args == 1 then
    path = tostring(args[1])
  else
    path = tostring(args[1])
    for i = 2, #args do
      path = vim.fs.joinpath(path, tostring(args[i]))
    end
  end

  return setmetatable({ _path = path }, Path)
end

Path.new = new

function Path:__tostring()
  return self._path
end

---@return string Absolute path with no trailing separator
function Path:absolute()
  local p = vim.fn.fnamemodify(self._path, ":p")
  -- Strip trailing separator (mirrors plenary behaviour)
  if p ~= sep and p:sub(-1) == sep then
    p = p:sub(1, -2)
  end
  return p
end

---@return boolean
function Path:exists()
  return vim.uv.fs_stat(self._path) ~= nil
end

---@return boolean
function Path:is_dir()
  local stat = vim.uv.fs_stat(self._path)
  return stat ~= nil and stat.type == "directory"
end

---@param ... string|NeogitPath Additional segments to append
---@return NeogitPath
function Path:joinpath(...)
  local result = self._path
  for _, segment in ipairs { ... } do
    result = vim.fs.joinpath(result, tostring(segment))
  end
  return new(result)
end

---Return the path relative to `base`. Returns the absolute path unchanged when
---it does not share the base prefix.
---@param base string|NeogitPath
---@return string
function Path:make_relative(base)
  local abs_self = self:absolute()
  local abs_base = vim.fn.fnamemodify(tostring(base), ":p")
  if abs_base ~= sep and abs_base:sub(-1) == sep then
    abs_base = abs_base:sub(1, -2)
  end

  if abs_self == abs_base then
    return "."
  elseif vim.startswith(abs_self, abs_base .. sep) then
    return abs_self:sub(#abs_base + 2)
  end

  return abs_self
end

---@return string|nil Full file content, or nil if unreadable
function Path:read()
  local f = io.open(self._path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

---@param content string
---@param mode string "w" to overwrite, "a" or "a+" to append
---@return boolean
function Path:write(content, mode)
  local io_mode = (mode == "a" or mode == "a+") and "a" or "w"
  local f = io.open(self._path, io_mode)
  if f then
    f:write(content)
    f:close()
    return true
  end
  return false
end

---@return string[] Lines of the file without trailing newlines
function Path:readlines()
  return vim.fn.readfile(self._path)
end

---Returns a line iterator over the file. The file handle is closed automatically
---when the last line has been consumed.
---@return fun(): string|nil
function Path:iter()
  local f = io.open(self._path, "r")
  if not f then
    return function()
      return nil
    end
  end

  return function()
    local line = f:read("*l")
    if line == nil then
      f:close()
    end
    return line
  end
end

---Create the file (and optionally its parent directories) if it does not exist.
---@param opts { parents: boolean }|nil
function Path:touch(opts)
  if opts and opts.parents then
    local parent = vim.fn.fnamemodify(self._path, ":h")
    if parent ~= "" then
      vim.fn.mkdir(parent, "p")
    end
  end

  if not self:exists() then
    local f = io.open(self._path, "a")
    if f then
      f:close()
    end
  end
end

---Delete the file.
function Path:rm()
  vim.uv.fs_unlink(self._path)
end

return Path
