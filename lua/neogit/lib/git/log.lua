local cli = require("neogit.lib.git.cli")
local diff_lib = require("neogit.lib.git.diff")
local util = require("neogit.lib.util")
local config = require("neogit.config")

local M = {}

local commit_header_pat = "([| ]*)(%*?)([| ]*)commit (%w+)"

---@class CommitLogEntry
---@field oid string the object id of the commit
---@field message string commit message
---@field level number the depth of the commit in the graph
---@field graph string the graph string
---@field author_name string the name of the author
---@field author_email string the email of the author
---@field author_date string when the author commited
---@field committer_name string the name of the committer
---@field committer_email string the email of the committer
---@field committer_date string when the committer commited
---@field description string a list of lines
---@field commit_arg string the passed argument of the git command
---@field diffs any[]

---Parses the provided list of lines into a CommitLogEntry
---@param raw string[]
---@return CommitLogEntry[]
function M.parse(raw)
  local commits = {}
  local idx = 1

  local function advance()
    idx = idx + 1
  end

  local function peek()
    return raw[idx]
  end

  while true do
    local line = peek()
    if not line then
      break
    end

    local commit = {}
    local s1, s2, star

    s1, star, s2, commit.oid = line:match(commit_header_pat)

    if not commit.oid or commit.oid == "" then
      error("Failed to parse line: " .. line)
      return {}
    end

    -- Consume this line
    advance()

    local start_idx = #s1 + #s2 + #star

    local function lpeek()
      return raw[idx] and raw[idx]:sub(start_idx + 1, -1) or nil
    end

    local map = {
      Merge = function()
        commit.merge = line:match("Merge:%s*(%w+) (%w+)")
      end,
      Author = function(line)
        commit.author_name, commit.author_email = line:match("Author:%s*(.+) <(.+)>")
      end,
      AuthorDate = function(line)
        commit.author_date = line:match("AuthorDate:%s*(.+)")
      end,
      Commit = function(line)
        commit.committer_name, commit.committer_email = line:match("Commit:%s*(.+) <(.+)>")
      end,
      CommitDate = function(line)
        commit.committer_date = line:match("CommitDate:%s*(.+)")
      end,
    }

    while true do
      line = lpeek()

      if not line or line:find("^%s*$") then
        break
      end

      local w = line:match("%w+")
      local handler = map[w]
      if handler then
        handler(line)
      else
        error(string.format("Unhandled git log header: %q at %q", w, line))
      end

      advance()
    end

    commit.description = {}
    commit.diffs = {}

    -- Consume initial whitespace
    advance()

    while true do
      line = lpeek()

      -- The commit message is indented or No commit message - go straight to diff
      if not line or not line:match("^    ") or line:match("^diff") then
        break
      end

      local msg = line:gsub("^%s*", "")
      table.insert(commit.description, msg)
      advance()
    end

    -- Skip the whitespace after the status if there was a description
    if commit.description[1] then
      advance()
    end

    -- Read diffs
    local current_diff = {}
    local in_diff = false

    while true do
      line = lpeek()

      -- Parse the last diff, if any, and begin a new one
      if not line or vim.startswith(line, "diff") then
        -- There was a previous diff, parse it
        if in_diff then
          table.insert(commit.diffs, diff_lib.parse(current_diff))
          current_diff = {}
        end

        in_diff = true
      elseif line == "" then -- A blank line signifies end of diffs
        -- Parse the last diff, consume the blankline, and exit
        if in_diff then
          table.insert(commit.diffs, diff_lib.parse(current_diff))
          current_diff = {}
        end

        advance()
        break
      end

      -- Collect each diff separately
      if line and in_diff then
        table.insert(current_diff, line)
      else
        -- If not in a diff, then the log does not contain diffs
        break
      end

      advance()
    end

    table.insert(commits, commit)
  end

  return commits
end

local function make_commit(entry, graph)
  local hash, subject, author_name, rel_date, ref_name, author_date, committer_name, committer_date, committer_email, author_email, body, signature_code =
    unpack(entry)

  if rel_date then
    rel_date, _ = rel_date:gsub(" ago$", "")
  end

  return {
    graph = graph,
    oid = hash,
    description = { subject, body },
    author_name = author_name,
    author_email = author_email,
    author_date = author_date,
    rel_date = rel_date,
    ref_name = ref_name,
    committer_date = committer_date,
    committer_name = committer_name,
    committer_email = committer_email,
    body = body,
    signature_code = signature_code,
    -- TODO: Remove below here
    hash = hash,
    message = subject,
  }
end

---@param output table
---@param graph  table parsed ANSI graph table
---@return CommitLogEntry[]
local function parse_log(output, graph)
  local commits = {}

  if vim.tbl_isempty(graph) then
    for i = 1, #output do
      table.insert(commits, make_commit(output[i]))
    end
  else
    local total_commits = #output
    local current_commit = 0

    local commit_lookup = {}
    for i = 1, #output do
      commit_lookup[output[i][1]] = output[i]
    end

    for i = 1, #graph do
      if current_commit == total_commits then
        break
      end

      local oid = graph[i][1].oid
      if oid then
        table.insert(commits, make_commit(commit_lookup[oid], graph[i]))
        current_commit = current_commit + 1
      else
        table.insert(commits, { graph = graph[i] })
      end
    end
  end

  return commits
end

---Parses log output to a table
---@param output table
---@return string[][]
local function split_output(output)
  output = table.concat(output, "\n")
  output = vim.split(output, "\31", { trimempty = true })
  output = util.map(output, function(line)
    return vim.split(vim.trim(line:gsub("\n", " ")), "\30")
  end)

  return output
end

local format_args = {
  "%H", -- Full Hash
  "%s", -- Subject
  "%aN", -- Author Name
  "%cr", -- Commit Date (Relative)
  "%D", -- Ref Name
  "%ad", -- Author Date
  "%cN", -- Committer Name
  "%cd", -- Committer Date
  "%ce", -- Committer Email
  "%ae", -- Author Email
  "%b", -- Body
  "%G?", -- Signature status
  "%x1F", -- Entry delimiter to split on (dec \31)
}
local format_delimiter = "%x1E" -- Field delimiter to split on (dec \30)

--- Ensure a max is passed to the list function to prevent accidentally getting thousands of results.
---@param options table
---@return table
local function ensure_max(options)
  if vim.fn.has("nvim-0.10") == 1 then
    if
      not vim.tbl_contains(options, function(item)
        return item:match("%-%-max%-count=%d+")
      end, { predicate = true })
    then
      table.insert(options, "--max-count=256")
    end
  else
    local has_max = false
    for _, v in ipairs(options) do
      if v:match("%-%-max%-count=%d+") then
        has_max = true
        break
      end
    end
    if not has_max then
      table.insert(options, "--max-count=256")
    end
  end

  return options
end

--- Checks to see if `--max-count` exceeds 256
---@param options table Arguments
---@return boolean Exceeds 256 or not
local function exceeds_max_default(options)
  for _, v in ipairs(options) do
    local count = tonumber(v:match("%-%-max%-count=(%d+)"))
    if count ~= nil and count > 256 then
      return true
    end
  end
  return false
end

--- Ensure a max is passed to the list function to prevent accidentally getting thousands of results.
---@param options table
---@return table, boolean
local function show_signature(options)
  local show_signature = false
  if vim.tbl_contains(options, "--show-signature") then
    -- Do not show signature when count > 256
    if not exceeds_max_default(options) then
      show_signature = true
    end

    util.remove_item_from_table(options, "--show-signature")
  end

  return options, show_signature
end

--- When no order is specified, and a graph is built, --topo-order needs to be used to match the default graph ordering.
--- @param options table
--- @param graph table|nil
--- @return table, string|nil
local function determine_order(options, graph)
  if
    (graph or {})[1]
    and not vim.tbl_contains(options, "--date-order")
    and not vim.tbl_contains(options, "--author-date-order")
    and not vim.tbl_contains(options, "--topo-order")
  then
    table.insert(options, "--topo-order")
  end

  return options
end

--- Parses the arguments needed for the format output of git log
---@param show_signature boolean Should '%G?' be omitted from the arguments
---@return string Concatenated format arguments
local function parse_log_format(show_signature)
  if not show_signature then
    return table.concat(
      vim.tbl_filter(function(value)
        return value ~= "%G?"
      end, format_args),
      format_delimiter
    )
  end
  return table.concat(format_args, format_delimiter)
end

---@param options table|nil
---@param files? table
---@param color boolean
---@return table
function M.graph(options, files, color)
  options = ensure_max(options or {})
  files = files or {}

  local result =
    cli.log.format("%x1E%H%x00").graph.color.arg_list(options).files(unpack(files)).call():trim().stdout_raw

  return util.filter_map(result, function(line)
    return require("neogit.lib.ansi").parse(util.trim(line), { recolor = not color })
  end)
end

---@param options? string[]
---@param graph? table
---@param files? table
---@return CommitLogEntry[]
function M.list(options, graph, files)
  files = files or {}
  local signature = false

  options = ensure_max(options or {})
  options = determine_order(options, graph)
  options, signature = show_signature(options)

  local output = cli.log
    .format(parse_log_format(signature))
    .arg_list(options)
    .files(unpack(files))
    .show_popup(false)
    .call()
    :trim().stdout

  return parse_log(split_output(output), graph or {})
end

---Determines if commit a is an ancestor of commit b
---@param a string commit hash
---@param b string commit hash
---@return boolean
function M.is_ancestor(a, b)
  return cli["merge-base"].is_ancestor.args(a, b):call_sync_ignoring_exit_code():trim().code == 0
end

local function update_recent(state)
  local count = config.values.status.recent_commit_count
  if count < 1 then
    return
  end

  state.recent.items = util.filter_map(M.list { "--max-count=" .. tostring(count) }, M.present_commit)
end

function M.register(meta)
  meta.update_recent = update_recent
end

function M.update_ref(from, to)
  cli["update-ref"].message(string.format("reset: moving to %s", to)).args(from, to).call()
end

function M.message(commit)
  return cli.log.format("%s").args(commit).call():trim().stdout[1]
end

function M.present_commit(commit)
  if not commit.oid then
    return
  end

  return {
    name = string.format("%s %s", commit.oid:sub(1, 7), commit.description[1] or "<empty>"),
    oid = commit.oid,
    commit = commit,
  }
end

--- Runs `git verify-commit`
---@param commit string Hash of commit
---@return string The stderr output of the command
function M.verify_commit(commit)
  return cli["verify-commit"].args(commit).call_sync_ignoring_exit_code():trim().stderr
end

return M
