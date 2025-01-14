local git = require("neogit.lib.git")
local process = require("neogit.process")
local util = require("neogit.lib.util")
local Path = require("plenary.path")
local runner = require("neogit.runner")

---@class GitCommandSetup
---@field flags table|nil
---@field options table|nil
---@field aliases table|nil
---@field short_opts table|nil

---@class GitCommand
---@field flags table
---@field options table
---@field aliases table
---@field short_opts table

---@class GitCommandBuilder
---@field args fun(...): self appends all params to cli as argument
---@field arguments fun(...): self alias for `args`
---@field arg_list fun(table): self unpacks table and uses items as cli arguments
---@field files fun(...): self any filepaths to append to the cli call
---@field paths fun(...): self alias for `files`
---@field input fun(string): self string to send to process via STDIN
---@field stdin fun(string): self alias for `input`
---@field prefix fun(string): self prefix for CLI call
---@field env fun(table): self key/value pairs to set as ENV variables for process
---@field in_pty fun(boolean): self should this be run in a PTY or not?
---@field call fun(CliCallOptions): ProcessResult

---@class CliCallOptions
---@field hidden boolean Is the command hidden from user?
---@field trim boolean remove blank lines from output?
---@field remove_ansi boolean remove ansi escape-characters from output?
---@field await boolean run synchronously if true
---@field long boolean is the command expected to be long running? (like git bisect, commit, rebase, etc)
---@field pty boolean run command in PTY?
---@field on_error fun(res: ProcessResult): boolean function to call if the process exits with status > 0. Used to
---                                                 determine how to handle the error, if user should be alerted or not

---@class GitCommandShow: GitCommandBuilder
---@field stat self
---@field oneline self
---@field no_patch self
---@field format fun(string): self
---@field file fun(name: string, rev: string|nil): self

---@class GitCommandNameRev: GitCommandBuilder
---@field name_only self
---@field no_undefined self
---@field refs fun(string): self
---@field exclude fun(string): self

---@class GitCommandInit: GitCommandBuilder

---@class GitCommandCheckoutIndex: GitCommandBuilder
---@field all self
---@field force self

---@class GitCommandWorktree: GitCommandBuilder
---@field add self
---@field list self
---@field move self
---@field remove self

---@class GitCommandRm: GitCommandBuilder
---@field cached self

---@class GitCommandMove: GitCommandBuilder

---@class GitCommandStatus: GitCommandBuilder
---@field short self
---@field branch self
---@field verbose self
---@field null_separated self
---@field porcelain fun(string): self

---@class GitCommandLog: GitCommandBuilder
---@field oneline self
---@field branches self
---@field remotes self
---@field all self
---@field graph self
---@field color self
---@field pretty fun(string): self
---@field max_count fun(string): self
---@field format fun(string): self

---@class GitCommandConfig: GitCommandBuilder
---@field _local self
---@field global self
---@field list self
---@field _get self PRIVATE - use alias
---@field _add self PRIVATE - use alias
---@field _unset self PRIVATE - use alias
---@field null self
---@field set fun(key: string, value: string): self
---@field unset fun(key: string): self
---@field get fun(path: string): self

---@class GitCommandDescribe: GitCommandBuilder
---@field long self
---@field tags self

---@class GitCommandDiff: GitCommandBuilder
---@field cached self
---@field stat self
---@field shortstat self
---@field patch self
---@field name_only self
---@field no_ext_diff self
---@field no_index self
---@field index self
---@field check self

---@class GitCommandStash: GitCommandBuilder
---@field apply self
---@field drop self
---@field push self
---@field store self
---@field index self
---@field staged self
---@field keep_index self
---@field message fun(text: string): self

---@class GitCommandTag: GitCommandBuilder
---@field n self
---@field list self
---@field delete self

---@class GitCommandRebase: GitCommandBuilder
---@field interactive self
---@field onto self
---@field edit_todo self
---@field continue self
---@field abort self
---@field skip self
---@field autosquash self
---@field autostash self
---@field commit fun(rev: string): self

---@class GitCommandMerge: GitCommandBuilder
---@field continue self
---@field abort self

---@class GitCommandMergeBase: GitCommandBuilder
---@field is_ancestor self

---@class GitCommandReset: GitCommandBuilder
---@field hard self
---@field mixed self
---@field soft self
---@field keep self
---@field merge self

---@class GitCommandCheckout: GitCommandBuilder
---@field b fun(): self
---@field _track self PRIVATE - use alias
---@field detach self
---@field ours self
---@field theirs self
---@field merge self
---@field track fun(branch: string): self
---@field rev fun(rev: string): self
---@field branch fun(branch: string): self
---@field commit fun(commit: string): self
---@field new_branch fun(new_branch: string): self
---@field new_branch_with_start_point fun(branch: string, start_point: string): self

---@class GitCommandRemote: GitCommandBuilder
---@field push self
---@field add self
---@field rm self
---@field rename self
---@field prune self
---@field get_url fun(remote: string): self

---@class GitCommandRevert: GitCommandBuilder
---@field no_commit self
---@field no_edit self
---@field continue self
---@field skip self
---@field abort self

---@class GitCommandApply: GitCommandBuilder
---@field ignore_space_change self
---@field cached self
---@field reverse self
---@field index self
---@field with_patch fun(string): self alias for input

---@class GitCommandAdd: GitCommandBuilder
---@field update self
---@field all self

---@class GitCommandAbsorb: GitCommandBuilder
---@field verbose self
---@field and_rebase self
---@field base fun(commit: string): self

---@class GitCommandCommit: GitCommandBuilder
---@field all self
---@field no_verify self
---@field amend self
---@field only self
---@field dry_run self
---@field no_edit self
---@field edit self
---@field allow_empty self
---@field with_message fun(message: string): self Passes message via STDIN
---@field message fun(message: string): self Passes message via CLI

---@class GitCommandPush: GitCommandBuilder
---@field delete self
---@field remote fun(remote: string): self
---@field to fun(to: string): self

---@class GitCommandPull: GitCommandBuilder
---@field no_commit self

---@class GitCommandCherry: GitCommandBuilder
---@field verbose self

---@class GitCommandBranch: GitCommandBuilder
---@field all self
---@field delete self
---@field remotes self
---@field force self
---@field current self
---@field edit_description self
---@field very_verbose self
---@field move self
---@field sort fun(sort: string): self
---@field set_upstream_to fun(name: string): self
---@field name fun(name: string): self

---@class GitCommandFetch: GitCommandBuilder
---@field recurse_submodules self
---@field verbose self
---@field jobs fun(n: number): self

---@class GitCommandReadTree: GitCommandBuilder
---@field merge self
---@field index_output fun(path: string): self
---@field tree fun(tree: string): self

---@class GitCommandWriteTree: GitCommandBuilder

---@class GitCommandCommitTree: GitCommandBuilder
---@field no_gpg_sign self
---@field parent fun(parent: string): self
---@field message fun(message: string): self
---@field parents fun(...): self
---@field tree fun(tree: string): self

---@class GitCommandUpdateIndex: GitCommandBuilder
---@field add self
---@field remove self
---@field refresh self

---@class GitCommandShowRef: GitCommandBuilder
---@field verify self

---@class GitCommandShowBranch: GitCommandBuilder
---@field all self

---@class GitCommandReflog: GitCommandBuilder
---@field show self
---@field format fun(format: string): self
---@field date fun(mode: string): self

---@class GitCommandUpdateRef: GitCommandBuilder
---@field create_reflog self
---@field message fun(text: string): self

---@class GitCommandLsFiles: GitCommandBuilder
---@field others self
---@field deleted self
---@field modified self
---@field cached self
---@field deduplicate self
---@field exclude_standard self
---@field full_name self
---@field error_unmatch self

---@class GitCommandLsTree: GitCommandBuilder
---@field full_tree self
---@field name_only self
---@field recursive self

---@class GitCommandLsRemote: GitCommandBuilder
---@field tags self
---@field remote fun(remote: string): self

---@class GitCommandForEachRef: GitCommandBuilder
---@field format self
---@field sort self

---@class GitCommandRevList: GitCommandBuilder
---@field merges self
---@field parents self
---@field max_count fun(n: number): self

---@class GitCommandRevParse: GitCommandBuilder
---@field verify self
---@field quiet self
---@field short self
---@field revs_only self
---@field no_revs self
---@field flags self
---@field no_flags self
---@field symbolic self
---@field symbolic_full_name self
---@field abbrev_ref fun(ref: string): self

---@class GitCommandCherryPick: GitCommandBuilder
---@field no_commit self
---@field continue self
---@field skip self
---@field abort self

---@class GitCommandVerifyCommit: GitCommandBuilder

---@class GitCommandBisect: GitCommandBuilder

---@class NeogitGitCLI
---@field absorb         GitCommandAbsorb
---@field add            GitCommandAdd
---@field apply          GitCommandApply
---@field bisect         GitCommandBisect
---@field branch         GitCommandBranch
---@field checkout       GitCommandCheckout
---@field checkout-index GitCommandCheckoutIndex
---@field cherry         GitCommandCherry
---@field cherry-pick    GitCommandCherryPick
---@field commit         GitCommandCommit
---@field commit-tree    GitCommandCommitTree
---@field config         GitCommandConfig
---@field describe       GitCommandDescribe
---@field diff           GitCommandDiff
---@field fetch          GitCommandFetch
---@field for-each-ref   GitCommandForEachRef
---@field init           GitCommandInit
---@field log            GitCommandLog
---@field ls-files       GitCommandLsFiles
---@field ls-remote      GitCommandLsRemote
---@field ls-tree        GitCommandLsTree
---@field merge          GitCommandMerge
---@field merge-base     GitCommandMergeBase
---@field name-rev       GitCommandNameRev
---@field pull           GitCommandPull
---@field push           GitCommandPush
---@field read-tree      GitCommandReadTree
---@field rebase         GitCommandRebase
---@field reflog         GitCommandReflog
---@field remote         GitCommandRemote
---@field revert         GitCommandRevert
---@field reset          GitCommandReset
---@field rev-list       GitCommandRevList
---@field rev-parse      GitCommandRevParse
---@field rm             GitCommandRm
---@field show           GitCommandShow
---@field show-branch    GitCommandShowBranch
---@field show-ref       GitCommandShowRef
---@field stash          GitCommandStash
---@field status         GitCommandStatus
---@field tag            GitCommandTag
---@field update-index   GitCommandUpdateIndex
---@field update-ref     GitCommandUpdateRef
---@field verify-commit  GitCommandVerifyCommit
---@field worktree       GitCommandWorktree
---@field write-tree     GitCommandWriteTree
---@field mv             GitCommandMove
---@field worktree_root fun(dir: string):string
---@field git_dir fun(dir: string):string
---@field worktree_git_dir fun(dir: string):string
---@field is_inside_worktree fun(dir: string):boolean
---@field history ProcessResult[]

---@param setup GitCommandSetup|nil
---@return GitCommand
local function config(setup)
  setup = setup or {}

  local command = {}
  command.flags = setup.flags or {}
  command.options = setup.options or {}
  command.aliases = setup.aliases or {}
  command.short_opts = setup.short_opts or {}

  return command
end

local configurations = {
  show = config {
    flags = {
      stat = "--stat",
      oneline = "--oneline",
      no_patch = "--no-patch",
    },
    options = {
      format = "--format",
    },
    aliases = {
      file = function(tbl)
        return function(name, rev)
          return tbl.args((rev or "") .. ":" .. name)
        end
      end,
    },
  },

  ["name-rev"] = config {
    flags = {
      name_only = "--name-only",
      no_undefined = "--no-undefined",
    },
    options = {
      refs = "--refs",
      exclude = "--exclude",
    },
  },

  init = config {},

  ["checkout-index"] = config {
    flags = {
      all = "--all",
      force = "--force",
    },
  },

  worktree = config {
    flags = {
      add = "add",
      list = "list",
      move = "move",
      remove = "remove",
    },
  },

  rm = config {
    flags = {
      cached = "--cached",
    },
  },

  status = config {
    flags = {
      short = "-s",
      branch = "-b",
      verbose = "-v",
      null_separated = "-z",
    },
    options = {
      porcelain = "--porcelain",
    },
  },

  log = config {
    flags = {
      oneline = "--oneline",
      branches = "--branches",
      remotes = "--remotes",
      all = "--all",
      graph = "--graph",
      color = "--color",
    },
    options = {
      pretty = "--pretty",
      max_count = "--max-count",
      format = "--format",
    },
  },

  config = config {
    flags = {
      _local = "--local",
      global = "--global",
      list = "--list",
      _get = "--get",
      _add = "--add",
      _unset = "--unset",
      null = "--null",
    },
    aliases = {
      set = function(tbl)
        return function(key, value)
          return tbl.arg_list { key, value }
        end
      end,
      unset = function(tbl)
        return function(key)
          return tbl._unset.args(key)
        end
      end,
      get = function(tbl)
        return function(path)
          return tbl._get.args(path)
        end
      end,
    },
  },

  describe = config {
    flags = {
      long = "--long",
      tags = "--tags",
    },
  },

  diff = config {
    flags = {
      cached = "--cached",
      stat = "--stat",
      shortstat = "--shortstat",
      patch = "--patch",
      name_only = "--name-only",
      no_ext_diff = "--no-ext-diff",
      no_index = "--no-index",
      check = "--check",
    },
  },

  stash = config {
    flags = {
      apply = "apply",
      drop = "drop",
      push = "push",
      store = "store",
      index = "--index",
      staged = "--staged",
      keep_index = "--keep-index",
    },
    aliases = {
      message = function(tbl)
        return function(text)
          return tbl.args("-m", text)
        end
      end,
    },
  },

  tag = config {
    flags = {
      n = "-n",
      list = "--list",
      delete = "--delete",
    },
  },

  rebase = config {
    flags = {
      interactive = "-i",
      onto = "--onto",
      edit_todo = "--edit-todo",
      continue = "--continue",
      abort = "--abort",
      skip = "--skip",
      autosquash = "--autosquash",
      autostash = "--autostash",
    },
    aliases = {
      commit = function(tbl)
        return function(rev)
          return tbl.args(rev .. "^")
        end
      end,
    },
  },

  merge = config {
    flags = {
      continue = "--continue",
      abort = "--abort",
    },
  },

  ["merge-base"] = config {
    flags = {
      is_ancestor = "--is-ancestor",
    },
  },

  reset = config {
    flags = {
      hard = "--hard",
      mixed = "--mixed",
      soft = "--soft",
      keep = "--keep",
      merge = "--merge",
    },
    aliases = {
      commit = function(tbl)
        return function(cm)
          return tbl.args(cm)
        end
      end,
    },
  },

  revert = config {
    flags = {
      no_commit = "--no-commit",
      continue = "--continue",
      no_edit = "--no-edit",
      skip = "--skip",
      abort = "--abort",
    },
  },

  mv = config {},

  checkout = config {
    short_opts = {
      b = "-b",
    },
    flags = {
      _track = "--track",
      detach = "--detach",
      ours = "--ours",
      theirs = "--theirs",
      merge = "--merge",
    },
    aliases = {
      track = function(tbl)
        return function(branch)
          return tbl._track.args(branch)
        end
      end,
      rev = function(tbl)
        return function(rev)
          return tbl.args(rev)
        end
      end,
      branch = function(tbl)
        return function(branch)
          return tbl.args(branch)
        end
      end,
      commit = function(tbl)
        return function(commit)
          return tbl.args(commit)
        end
      end,
      new_branch = function(tbl)
        return function(branch)
          return tbl.b(branch)
        end
      end,
      new_branch_with_start_point = function(tbl)
        return function(branch, start_point)
          return tbl.args(branch, start_point).b()
        end
      end,
    },
  },

  remote = config {
    flags = {
      push = "--push",
      add = "add",
      rm = "rm",
      rename = "rename",
      prune = "prune",
    },
    aliases = {
      get_url = function(tbl)
        return function(remote)
          return tbl.args("get-url", remote)
        end
      end,
    },
  },

  apply = config {
    flags = {
      ignore_space_change = "--ignore-space-change",
      cached = "--cached",
      reverse = "--reverse",
      index = "--index",
    },
    aliases = {
      with_patch = function(tbl)
        return tbl.input
      end,
    },
  },

  add = config {
    flags = {
      update = "-u",
      all = "-A",
    },
  },

  absorb = config {
    flags = {
      verbose = "--verbose",
      and_rebase = "--and-rebase",
    },
    aliases = {
      base = function(tbl)
        return function(commit)
          return tbl.args("--base", commit)
        end
      end,
    },
  },

  commit = config {
    flags = {
      all = "--all",
      no_verify = "--no-verify",
      amend = "--amend",
      only = "--only",
      dry_run = "--dry-run",
      no_edit = "--no-edit",
      edit = "--edit",
      allow_empty = "--allow-empty",
    },
    aliases = {
      with_message = function(tbl)
        return function(message)
          return tbl.args("-F", "-").input(message)
        end
      end,
      message = function(tbl)
        return function(message)
          return tbl.args("-m", message)
        end
      end,
    },
  },

  push = config {
    flags = {
      delete = "--delete",
    },
    aliases = {
      remote = function(tbl)
        return function(remote)
          return tbl.prefix(remote)
        end
      end,
      to = function(tbl)
        return function(to)
          return tbl.args(to)
        end
      end,
    },
  },

  pull = config {
    flags = {
      no_commit = "--no-commit",
    },
  },

  cherry = config {
    flags = {
      verbose = "-v",
    },
  },

  branch = config {
    flags = {
      all = "-a",
      delete = "-d",
      remotes = "-r",
      force = "--force",
      current = "--show-current",
      edit_description = "--edit-description",
      very_verbose = "-vv",
      move = "-m",
    },
    options = {
      sort = "--sort",
      set_upstream_to = "--set-upstream-to",
    },
    aliases = {
      name = function(tbl)
        return function(name)
          return tbl.args(name)
        end
      end,
    },
  },

  fetch = config {
    flags = {
      recurse_submodules = "--recurse-submodules",
      verbose = "--verbose",
    },
    options = {
      jobs = "--jobs",
    },
  },

  ["read-tree"] = config {
    flags = {
      merge = "-m",
    },
    options = {
      index_output = "--index-output",
    },
    aliases = {
      tree = function(tbl)
        return function(tree)
          return tbl.args(tree)
        end
      end,
    },
  },

  ["write-tree"] = config {},

  ["commit-tree"] = config {
    flags = {
      no_gpg_sign = "--no-gpg-sign",
    },
    short_opts = {
      parent = "-p",
      message = "-m",
    },
    aliases = {
      parents = function(tbl)
        return function(...)
          for _, p in ipairs { ... } do
            tbl.parent(p)
          end
          return tbl
        end
      end,
      tree = function(tbl)
        return function(tree)
          return tbl.args(tree)
        end
      end,
    },
  },

  ["update-index"] = config {
    flags = {
      add = "--add",
      remove = "--remove",
      refresh = "--refresh",
    },
  },

  ["show-ref"] = config {
    flags = {
      verify = "--verify",
    },
  },

  ["show-branch"] = config {
    flags = {
      all = "--all",
    },
  },

  reflog = config {
    flags = {
      show = "show",
    },
    options = {
      format = "--format",
    },
    aliases = {
      date = function(tbl)
        return function(mode)
          return tbl.args("--date=" .. mode)
        end
      end,
    },
  },

  ["update-ref"] = config {
    flags = {
      create_reflog = "--create-reflog",
    },
    aliases = {
      message = function(tbl)
        return function(text)
          -- TODO: Is this escapement needed?
          local escaped_text, _ = text:gsub([["]], [[\"]])
          return tbl.args("-m", string.format([["%s"]], escaped_text))
        end
      end,
    },
  },

  ["ls-files"] = config {
    flags = {
      others = "--others",
      deleted = "--deleted",
      modified = "--modified",
      cached = "--cached",
      deduplicate = "--deduplicate",
      exclude_standard = "--exclude-standard",
      full_name = "--full-name",
      error_unmatch = "--error-unmatch",
    },
  },

  ["ls-tree"] = config {
    flags = {
      full_tree = "--full-tree",
      name_only = "--name-only",
      recursive = "-r",
    },
  },

  ["ls-remote"] = config {
    flags = {
      tags = "--tags",
    },
    aliases = {
      remote = function(tbl)
        return function(remote)
          return tbl.args(remote)
        end
      end,
    },
  },

  ["for-each-ref"] = config {
    options = {
      format = "--format",
      sort = "--sort",
    },
  },

  ["rev-list"] = config {
    flags = {
      merges = "--merges",
      parents = "--parents",
    },
    options = {
      max_count = "--max-count",
    },
  },

  ["rev-parse"] = config {
    flags = {
      verify = "--verify",
      quiet = "--quiet",
      short = "--short",
      revs_only = "--revs-only",
      no_revs = "--no-revs",
      flags = "--flags",
      no_flags = "--no-flags",
      symbolic = "--symbolic",
      symbolic_full_name = "--symbolic-full-name",
    },
    options = {
      abbrev_ref = "--abbrev-ref",
    },
  },

  ["cherry-pick"] = config {
    flags = {
      no_commit = "--no-commit",
      continue = "--continue",
      skip = "--skip",
      abort = "--abort",
    },
  },

  ["verify-commit"] = config {},

  ["bisect"] = config {},
}

--- NOTE: Use require("neogit.lib.git").repo.worktree_root instead of calling this function.
--- repository.worktree_root is used by all other library functions, so it's most likely the one you want to use.
--- worktree_root_of_cwd() returns the git repo of the cwd, which can change anytime
--- after worktree_root_of_cwd() has been called.
---@param dir string
---@return string Absolute path of current worktree
local function worktree_root(dir)
  local cmd = { "git", "-C", dir, "rev-parse", "--show-toplevel" }
  local result = vim.system(cmd, { text = true }):wait()

  return Path:new(vim.trim(result.stdout)):absolute()
end

---@param dir string
---@return string Absolute path of `.git/` directory
local function git_dir(dir)
  local cmd = { "git", "-C", dir, "rev-parse", "--git-common-dir" }
  local result = vim.system(cmd, { text = true }):wait()

  return Path:new(vim.trim(result.stdout)):absolute()
end

---@param dir string
---@return string Absolute path of `.git/` directory
local function worktree_git_dir(dir)
  local cmd = { "git", "-C", dir, "rev-parse", "--git-dir" }
  local result = vim.system(cmd, { text = true }):wait()

  return Path:new(vim.trim(result.stdout)):absolute()
end

---@param dir string
---@return boolean
local function is_inside_worktree(dir)
  local cmd = { "git", "-C", dir, "rev-parse", "--is-inside-work-tree" }
  local result = vim.system(cmd):wait()

  return result.code == 0
end

local k_state = {}
local k_config = {}
local k_command = {}

local mt_builder = {
  __index = function(tbl, action)
    if action == "args" or action == "arguments" then
      return function(...)
        for _, v in ipairs { ... } do
          table.insert(tbl[k_state].arguments, v)
        end
        return tbl
      end
    end

    if action == "arg_list" then
      return function(args)
        for _, v in ipairs(args) do
          table.insert(tbl[k_state].arguments, v)
        end
        return tbl
      end
    end

    if action == "files" or action == "paths" then
      return function(...)
        for _, v in ipairs { ... } do
          table.insert(tbl[k_state].files, v)
        end
        return tbl
      end
    end

    if action == "input" or action == "stdin" then
      return function(value)
        tbl[k_state].input = value
        return tbl
      end
    end

    if action == "prefix" then
      return function(x)
        tbl[k_state].prefix = x
        return tbl
      end
    end

    if action == "env" then
      return function(cfg)
        for k, v in pairs(cfg) do
          tbl[k_state].env[k] = v
        end
        return tbl
      end
    end

    if action == "in_pty" then
      return function(in_pty)
        tbl[k_state].in_pty = in_pty
        return tbl
      end
    end

    if tbl[k_config].flags[action] then
      table.insert(tbl[k_state].options, tbl[k_config].flags[action])
      return tbl
    end

    if tbl[k_config].options[action] then
      return function(value)
        if value then
          table.insert(tbl[k_state].options, string.format("%s=%s", tbl[k_config].options[action], value))
        else
          table.insert(tbl[k_state].options, tbl[k_config].options[action])
        end
        return tbl
      end
    end

    if tbl[k_config].short_opts[action] then
      return function(value)
        table.insert(tbl[k_state].options, tbl[k_config].short_opts[action])
        table.insert(tbl[k_state].options, value)
        return tbl
      end
    end

    if tbl[k_config].aliases[action] then
      return tbl[k_config].aliases[action](tbl, tbl[k_state])
    end

    error("unknown field: " .. action)
  end,
  __tostring = function(tbl)
    return string.format(
      "git %s %s %s -- %s",
      tbl[k_command],
      table.concat(tbl[k_state].options, " "),
      table.concat(tbl[k_state].arguments, " "),
      table.concat(tbl[k_state].files, " ")
    )
  end,
  __call = function(tbl, ...)
    return tbl.call(...)
  end,
}

local function new_builder(subcommand)
  local configuration = configurations[subcommand]
  if not configuration then
    error("Command not found")
  end

  local state = {
    options = {},
    arguments = {},
    files = {},
    input = nil,
    in_pty = false,
    env = {},
  }

  local function to_process(opts)
    local cmd = {}

    for _, o in ipairs(state.options) do
      table.insert(cmd, o)
    end

    for _, arg in ipairs(state.arguments) do
      if arg ~= "" then
        table.insert(cmd, arg)
      end
    end

    if #state.files > 0 then
      table.insert(cmd, "--")

      for _, f in ipairs(state.files) do
        table.insert(cmd, f)
      end
    end

    if state.prefix then
      table.insert(cmd, 1, state.prefix)
    end

    if state.input and cmd[#cmd] ~= "-" then
      table.insert(cmd, "-")
    end

    -- stylua: ignore
    cmd = util.merge(
      {
        "git",
        "--no-pager",
        "--literal-pathspecs",
        "--no-optional-locks",
        "-c", "core.preloadindex=true",
        "-c", "color.ui=always",
        subcommand
      },
      cmd
    )

    return process.new {
      cmd = cmd,
      cwd = git.repo.worktree_root,
      env = state.env,
      input = state.input,
      on_error = opts.on_error,
      pty = state.in_pty,
      git_hook = git.hooks.exists(subcommand) and not vim.tbl_contains(cmd, "--no-verify"),
      suppress_console = not not (opts.hidden or opts.long),
      user_command = false,
    }
  end

  ---@return CliCallOptions
  local function make_options(options)
    local opts = vim.tbl_extend("keep", (options or {}), {
      hidden = false,
      trim = true,
      remove_ansi = true,
      await = false,
      long = false,
      pty = false,
    })

    if opts.pty then
      opts.await = false
    end

    opts.on_error = function(res)
      -- When aborting, don't alert the user. exit(1) is expected.
      for _, line in ipairs(res.stdout) do
        if
          line:match("^hint: Waiting for your editor to close the file...")
          or line:match("error: there was a problem with the editor")
        then
          return false
        end
      end

      -- When opening in a brand new repo, HEAD will cause an error.
      if
        res.stderr[1]
        == "fatal: ambiguous argument 'HEAD': unknown revision or path not in the working tree."
      then
        return false
      end

      return not opts.ignore_error
    end

    return opts
  end

  return setmetatable({
    [k_state] = state,
    [k_config] = configuration,
    [k_command] = subcommand,
    to_process = to_process,
    call = function(options)
      local opts = make_options(options)
      local p = to_process(opts)

      return runner.call(p, opts)
    end,
  }, mt_builder)
end

local meta = {
  __index = function(_, key)
    if configurations[key] then
      return new_builder(key)
    end

    error("unknown field: " .. key)
  end,
}

local cli = setmetatable({
  history = runner.history,
  worktree_root = worktree_root,
  worktree_git_dir = worktree_git_dir,
  git_dir = git_dir,
  is_inside_worktree = is_inside_worktree,
}, meta)

return cli
