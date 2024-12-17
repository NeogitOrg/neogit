local git = require("neogit.lib.git")
local util = require("neogit.lib.util")
local config = require("neogit.config")
local record = require("neogit.lib.record")

---@class NeogitGitLog
local M = {}

local commit_header_pat = "([| ]*)(%*?)([| ]*)commit (%w+)"

---@class CommitLogEntry
---@field oid string the object id of the commit
---@field message string commit message
---@field level number the depth of the commit in the graph
---@field graph string the graph string
---@field author_name string the name of the author
---@field author_email string the email of the author
---@field author_date string when the author committed
---@field committer_name string the name of the committer
---@field committer_email string the email of the committer
---@field committer_date string when the committer committed
---@field description string a list of lines
---@field commit_arg string the passed argument of the git command
---@field subject string
---@field parent string
---@field diffs any[]
---@field ref_name string
---@field abbreviated_commit string
---@field body string
---@field verification_flag string?
---@field rel_date string
---@field log_date string

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
          table.insert(commit.diffs, git.diff.parse(current_diff, {}))
          current_diff = {}
        end

        in_diff = true
      elseif line == "" then -- A blank line signifies end of diffs
        -- Parse the last diff, consume the blankline, and exit
        if in_diff then
          table.insert(commit.diffs, git.diff.parse(current_diff, {}))
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
  entry.graph = graph
  entry.description = { entry.subject, entry.body }

  if entry.rel_date then
    entry.rel_date, _ = entry.rel_date:gsub(" ago$", "")
  end

  return entry
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
      commit_lookup[output[i]["oid"]] = output[i]
    end

    for i = 1, #graph do
      if current_commit == total_commits then
        break
      end

      local oid = graph[i][1].oid
      if oid then
        local commit = commit_lookup[oid]
        assert(commit, "No commit found for oid: " .. oid)

        table.insert(commits, make_commit(commit, graph[i]))
        current_commit = current_commit + 1
      else
        table.insert(commits, { graph = graph[i] })
      end
    end
  end

  return commits
end

--- Ensure a max is passed to the list function to prevent accidentally getting thousands of results.
---@param options table
---@return table
local function ensure_max(options)
  if
    not vim.tbl_contains(options, function(item)
      return item:match("%-%-max%-count=%d+")
    end, { predicate = true })
  then
    table.insert(options, "--max-count=256")
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
    graph
    and not vim.tbl_contains(options, "--date-order")
    and not vim.tbl_contains(options, "--author-date-order")
    and not vim.tbl_contains(options, "--topo-order")
  then
    table.insert(options, "--topo-order")
  end

  return options
end

--- Specifies date format when not using relative dates
--- @param options table
--- @return table, string|nil
local function set_date_format(options)
  if config.values.log_date_format ~= nil then
    table.insert(options, "--date=format:" .. config.values.log_date_format)
  end

  return options
end

---@param options table|nil
---@param files? table
---@param color? boolean
---@return table
M.graph = util.memoize(function(options, files, color)
  options = ensure_max(options or {})
  files = files or {}

  local result = git.cli.log
    .format("%x1E%H%x00").graph.color
    .arg_list(options)
    .files(unpack(files))
    .call({ ignore_error = true, hidden = true, remove_ansi = false }).stdout

  return util.filter_map(result, function(line)
    return require("neogit.lib.ansi").parse(util.trim(line), { recolor = not color })
  end)
end)

local function format(show_signature)
  local fields = {
    oid = "%H",
    abbreviated_commit = "%h",
    tree = "%T",
    abbreviated_tree = "%t",
    parent = "%P",
    abbreviated_parent = "%p",
    ref_name = "%D",
    encoding = "%e",
    subject = "%s",
    sanitized_subject_line = "%f",
    body = "%b",
    commit_notes = "%N",
    author_name = "%aN",
    author_email = "%aE",
    author_date = "%aD",
    committer_name = "%cN",
    committer_email = "%cE",
    committer_date = "%cD",
    rel_date = "%cr",
    log_date = "%cd",
  }

  if show_signature then
    fields.signer = "%GS"
    fields.signer_key = "%GK"
    fields.verification_flag = "%G?"
  end

  return record.encode(fields, "log")
end

---@param options? string[]
---@param graph? table
---@param files? table
---@param hidden? boolean Hide from git history
---@param graph_color? boolean Render ascii graph in color
---@return CommitLogEntry[]
M.list = util.memoize(function(options, graph, files, hidden, graph_color)
  files = files or {}

  local signature = false

  options = ensure_max(options or {})
  options = determine_order(options, graph)
  options, signature = show_signature(options)
  options = set_date_format(options)

  local output = git.cli.log
    .format(format(signature))
    .args("--no-patch")
    .arg_list(options)
    .files(unpack(files))
    .call({ hidden = hidden, ignore_error = hidden }).stdout

  local commits = record.decode(output) ---@type CommitLogEntry[]
  if vim.tbl_isempty(commits) then
    return {}
  end

  local graph_output
  if graph then
    if config.values.graph_style == "unicode" then
      graph_output = require("neogit.lib.graph.unicode").build(commits)
    elseif config.values.graph_style == "kitty" then
      graph_output = require("neogit.lib.graph.kitty").build(commits, graph_color)
    elseif config.values.graph_style == "ascii" then
      util.remove_item_from_table(options, "--show-signature")
      graph_output = M.graph(options, files, graph_color)
    end
  else
    graph_output = {}
  end

  return parse_log(commits, graph_output)
end)

---Determines if commit a is an ancestor of commit b
---@param ancestor string commit hash
---@param descendant string commit hash
---@return boolean
function M.is_ancestor(ancestor, descendant)
  return git.cli["merge-base"].is_ancestor
    .args(ancestor, descendant)
    .call({ ignore_error = true, hidden = true }).code == 0
end

---Finds parent commit of a commit. If no parent exists, will return nil
---@param commit string
---@return string|nil
function M.parent(commit)
  return vim.split(
    git.cli["rev-list"].max_count(1).parents.args(commit).call({ hidden = true }).stdout[1],
    " "
  )[2]
end

function M.register(meta)
  meta.update_recent = function(state)
    state.recent = { items = {} }

    local count = config.values.status.recent_commit_count
    if count > 0 then
      state.recent.items =
        util.filter_map(M.list({ "--max-count=" .. tostring(count) }, nil, {}, true), M.present_commit)
    end
  end
end

---@param from string
---@param to string
function M.update_ref(from, to)
  git.cli["update-ref"].message(string.format("reset: moving to %s", to)).args(from, to).call()
end

function M.message(commit)
  return git.cli.log.max_count(1).format("%s").args(commit).call({ hidden = true }).stdout[1]
end

function M.full_message(commit)
  return git.cli.log.max_count(1).format("%B").args(commit).call({ hidden = true }).stdout
end

---@class CommitItem
---@field name string
---@field oid string
---@field decoration CommitBranchInfo
---@field commit CommitLogEntry[]

---@return nil|CommitItem
function M.present_commit(commit)
  if not commit.oid then
    return
  end

  return {
    name = string.format("%s %s", commit.abbreviated_commit, commit.subject or "<empty>"),
    decoration = M.branch_info(commit.ref_name, git.remote.list()),
    oid = commit.oid,
    commit = commit,
  }
end

--- Runs `git verify-commit`
---@param commit string Hash of commit
---@return string[] The stderr output of the command
function M.verify_commit(commit)
  return git.cli["verify-commit"].args(commit).call({ ignore_error = true }).stderr
end

---@class CommitBranchInfo
---@field head string? The name of the local branch, which is currently checked out (if any)
---@field locals table<string,boolean> Set of local branch names
---@field remotes table<string, string[]> table<string, string[]> Mapping from (local) branch names to list of remotes where this branch is present
---@field tags string[] List of tags placed on this commit

---Parse information of branches, tags and remotes from a given commit's ref output
---@param ref string comma separated list of branches, tags and remotes, e.g.:
---   * "origin/main, main, origin/HEAD, tag: 1.2.3, fork/develop"
---   * "HEAD -> main, origin/main, origin/HEAD, tag: 1.2.3, fork/develop"
---@param remotes string[] list of remote names, e.g. by calling `require("neogit.lib.git").remote.list()`
---@return CommitBranchInfo
M.branch_info = util.memoize(function(ref, remotes)
  local parts = vim.split(ref, ", ")
  local result = {
    head = nil,
    locals = {},
    remotes = {},
    tags = {},
  }

  for _, name in pairs(parts) do
    local skip = false
    if name:match("^tag: .*") ~= nil then
      local tag = name:gsub("tag: ", "")
      table.insert(result.tags, tag)
      skip = true
    end

    if name:match("HEAD %-> ") then
      name = name:gsub("HEAD %-> ", "")
      result.head = name
    end

    local remote = nil
    for _, r in ipairs(remotes) do
      if not skip then
        if name:match("^" .. r .. "/") then
          name = name:gsub("^" .. r .. "/", "")
          if name == "HEAD" then
            skip = true
          else
            remote = r
          end
        end
      end
    end

    if not skip then
      if remote ~= nil then
        if result.remotes[name] == nil then
          result.remotes[name] = {}
        end
        table.insert(result.remotes[name], remote)
      else
        if name == "HEAD" then
          result.locals["@"] = true
        elseif name ~= "" then
          result.locals[name] = true
        end
      end
    end
  end

  return result
end)

function M.reflog_message(skip)
  return git.cli.log
    .format("%B")
    .max_count(1)
    .args("--reflog", "--no-merges", "--skip=" .. tostring(skip))
    .call({ ignore_error = true }).stdout
end

M.abbreviated_size = util.memoize(function()
  local commits = M.list({ "HEAD", "--max-count=1" }, nil, {}, true)
  if vim.tbl_isempty(commits) then
    return 7
  else
    return string.len(commits[1].abbreviated_commit)
  end
end, { timeout = math.huge })

function M.decorate(oid)
  local result = git.cli.log.format("%D").max_count(1).args(oid).call().stdout

  if result[1] == nil then
    return oid
  else
    local decorated_ref = vim.split(result[1], ",")[1]
    if decorated_ref:match("%->") then
      return oid
    else
      return decorated_ref
    end
  end
end

return M
