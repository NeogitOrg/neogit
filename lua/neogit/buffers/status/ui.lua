-- TODO
-- - Get fold markers to work
--
local Ui = require("neogit.lib.ui")
local Component = require("neogit.lib.ui.component")
local util = require("neogit.lib.util")
local common = require("neogit.buffers.common")
local a = require("plenary.async")

local col = Ui.col
local row = Ui.row
local text = Ui.text

local map = util.map

local List = common.List
local DiffHunks = common.DiffHunks
local EmptyLine = col { row { text("") } }

local M = {}

local HINT = Component.new(function(props)
  ---@return table<string, string[]>
  local function reversed_lookup(tbl)
    local result = {}
    for k, v in pairs(tbl) do
      if v then
        local current = result[v]
        if current then
          table.insert(current, k)
        else
          result[v] = { k }
        end
      end
    end

    return result
  end

  local reversed_status_map = reversed_lookup(props.config.mappings.status)
  local reversed_popup_map = reversed_lookup(props.config.mappings.popup)

  local entry = function(name, hint)
    local keys = reversed_status_map[name] or reversed_popup_map[name]
    local key_hint

    if keys and #keys > 0 then
      key_hint = table.concat(keys, " ")
    else
      key_hint = "<unmapped>"
    end

    return row {
      text.highlight("NeogitPopupActionKey")(key_hint),
      text(" "),
      text(hint),
    }
  end

  return row {
    text.highlight("Comment")("Hint: "),
    entry("Toggle", "toggle"),
    text.highlight("Comment")(" | "),
    entry("Stage", "stage"),
    text.highlight("Comment")(" | "),
    entry("Unstage", "unstage"),
    text.highlight("Comment")(" | "),
    entry("Discard", "discard"),
    text.highlight("Comment")(" | "),
    entry("CommitPopup", "commit"),
    text.highlight("Comment")(" | "),
    entry("HelpPopup", "help"),
  }
end)

local HEAD = Component.new(function(props)
  local highlight = props.remote and "NeogitRemote" or "NeogitBranch"
  local ref = props.remote and ("%s/%s"):format(props.remote, props.branch) or props.branch

  return row({
    text(util.pad_right(props.name .. ":", 10)),
    text.highlight(highlight)(ref),
    text(" "),
    text(props.msg or "(no commits)"),
  }, { yankable = props.yankable })
end)

local Tag = Component.new(function(props)
  return row({
    text(util.pad_right("Tag:", 10)),
    text.highlight("NeogitTagName")(props.name),
    text(" ("),
    text.highlight("NeogitTagDistance")(props.distance),
    text(")"),
  }, { yankable = props.yankable })
end)

local SectionTitle = Component.new(function(props)
  return { text.highlight("NeogitSectionHeader")(props.title) }
end)

local SectionTitleRemote = Component.new(function(props)
  return {
    text.highlight("NeogitSectionHeader")(props.title),
    text(" "),
    text.highlight("NeogitRemote")(props.ref),
  }
end)

-- TODO: Determine if 'onto' is local or remote
local SectionTitleRebase = Component.new(function(props)
  return {
    text.highlight("NeogitSectionHeader")(props.title),
    text(" "),
    text.highlight("NeogitBranch")(props.head),
    text.highlight("NeogitSectionHeader")(" onto "),
    text.highlight("NeogitBranch")(props.onto),
  }
end)

local Section = Component.new(function(props)
  return col.tag("Section")({
    row(util.merge(props.title, { text(" ("), text(#props.items), text(")") })),
    col(map(props.items, props.render)),
    EmptyLine,
  }, { foldable = true, folded = props.folded, section = props.name })
end)

local SectionItemFile = Component.new(function(item)
  local load_diff = function(item)
    ---@param this Component
    ---@param ui Ui
    ---@param prefix string|nil
    return a.void(function(this, ui, prefix)
      this.options.on_open = nil
      this.options.folded = false

      local row, _ = this:row_range_abs()
      row = row + 1 -- Filename row

      local diff = item.diff
      for _, hunk in ipairs(diff.hunks) do
        hunk.first = row
        hunk.last = row + hunk.length
        row = hunk.last + 1

        -- Set fold state when called from ui:update()
        if prefix then
          local key = ("%s--%s"):format(prefix, hunk.hash)
          if ui._old_node_attributes and ui._old_node_attributes[key] then
            hunk._folded = ui._old_node_attributes[key].folded
          end
        end
      end

      this:append(DiffHunks(diff))
      ui:update()
    end)
  end

  local mode_to_text = {
    M = "Modified",
    N = "New File",
    A = "Added",
    D = "Deleted",
    C = "Copied",
    U = "Updated",
    UU = "Both Modified",
    R = "Renamed",
    ["?"] = "", -- Untracked
  }

  local conflict = false
  local mode = mode_to_text[item.mode]
  if mode == nil then
    conflict = true
    mode = mode_to_text[item.mode:sub(1, 1)]
  end

  local highlight = ("NeogitChange%s"):format(mode:gsub(" ", ""))

  local mode_text
  if mode == "" then
    mode_text = ""
  elseif conflict then
    mode_text = util.pad_right(("%s by us"):format(mode), 15)
  else
    mode_text = util.pad_right(mode, 15)
  end

  return col.tag("SectionItemFile")({
    row {
      text.highlight(highlight)(mode_text),
      text(item.original_name and ("%s -> %s"):format(item.original_name, item.name) or item.name),
    },
  }, {
    foldable = true,
    folded = true,
    on_open = load_diff(item),
    context = true,
    yankable = item.name,
    filename = item.name,
    item = item,
  })
end)

local SectionItemStash = Component.new(function(item)
  local name = ("stash@{%s}"):format(item.idx)
  return row({
    text.highlight("Comment")(name),
    text.highlight("Comment")(": "),
    text(item.message),
  }, { yankable = name })
end)

local SectionItemCommit = Component.new(function(item)
  return row({
    text.highlight("Comment")(item.commit.abbreviated_commit),
    text(" "),
    text(item.commit.subject),
  }, { yankable = item.commit.oid })
end)

local SectionItemRebase = Component.new(function(item)
  if item.oid then
    local action_hl = (item.done and "NeogitRebaseDone")
      or (item.action == "onto" and "NeogitGraphBlue")
      or "NeogitGraphOrange"

    return row({
      text(item.stopped and "> " or "  "),
      text.highlight(action_hl)(util.pad_right(item.action, 6)),
      text(" "),
      text.highlight("NeogitRebaseDone")(item.oid:sub(1, 7)),
      text(" "),
      text.highlight(item.done and "NeogitRebaseDone")(item.subject),
    }, { yankable = item.oid })
  else
    return row {
      text.highlight("NeogitGraphOrange")(item.action),
      text(" "),
      text(item.subject),
    }
  end
end)

-- TODO: "gone", "work", "onto" highlighting
local SectionItemRevert = Component.new(function(item)
  local action_hl = (item.action == "work" and "NeogitGraphRed")
    or (item.action == "onto" and "NeogitGraphBlue")
    or "NeogitGraphOrange"

  return row({
    text.highlight(action_hl)(util.pad_right(item.action, 6)),
    text(" "),
    text.highlight("Comment")(item.oid:sub(1, 7)),
    text(" "),
    text(item.subject),
  }, { yankable = item.oid })
end)

function M.Status(state, config)
  -- stylua: ignore start
  local show_hint = not config.disable_hint

  local show_upstream = state.upstream.ref
    and state.head.branch ~= "(detached)"

  local show_pushRemote = state.pushRemote.ref
    and state.head.branch ~= "(detached)"

  local show_tag = state.head.tag.name
    and state.head.branch ~= "(detached)"

  local show_rebase = #state.rebase.items > 0
    and not config.sections.rebase.hidden

  local show_cherry_pick = #state.sequencer.items > 0
    and state.sequencer.cherry_pick
    and not config.sections.sequencer.hidden

  local show_revert = #state.sequencer.items > 0
    and state.sequencer.revert
    and not config.sections.sequencer.hidden

  local show_untracked = #state.untracked.items > 0
    and not config.sections.untracked.hidden

  local show_unstaged = #state.unstaged.items > 0
    and not config.sections.unstaged.hidden

  local show_staged = #state.staged.items > 0
    and not config.sections.staged.hidden

  local show_upstream_unpulled = #state.upstream.unpulled.items > 0
    and not config.sections.unpulled_upstream.hidden

  local show_pushRemote_unpulled = #state.pushRemote.unpulled.items > 0
    and state.pushRemote.ref ~= state.upstream.ref
    and not config.sections.unpulled_pushRemote.hidden

  local show_upstream_unmerged = #state.upstream.unmerged.items > 0
    and not config.sections.unmerged_upstream.hidden

  local show_pushRemote_unmerged = #state.pushRemote.unmerged.items > 0
    and state.pushRemote.ref ~= state.upstream.ref
    and not config.sections.unmerged_pushRemote.hidden

  local show_stashes = #state.stashes.items > 0
    and not config.sections.stashes.hidden

  local show_recent = #state.recent.items > 0
    and not config.sections.recent.hidden
  -- stylua: ignore end

  return {
    List {
      items = {
        show_hint and HINT { config = config },
        show_hint and EmptyLine,
        HEAD {
          name = "Head",
          branch = state.head.branch,
          msg = state.head.commit_message,
          yankable = state.head.oid,
        },
        show_upstream and HEAD {
          name = "Merge",
          branch = state.upstream.branch,
          remote = state.upstream.remote,
          msg = state.upstream.commit_message,
          yankable = state.upstream.oid,
        },
        show_pushRemote and HEAD {
          name = "Push",
          branch = state.pushRemote.branch,
          remote = state.pushRemote.remote,
          msg = state.pushRemote.commit_message,
          yankable = state.pushRemote.oid,
        },
        show_tag and Tag {
          name = state.head.tag.name,
          distance = state.head.tag.distance,
          yankable = state.head.tag.oid,
        },
        EmptyLine,
        show_rebase and Section {
          title = SectionTitleRebase {
            title = "Rebasing",
            head = state.rebase.head,
            onto = state.rebase.onto.ref,
          },
          render = SectionItemRebase,
          items = state.rebase.items,
          folded = config.sections.rebase.folded,
          name = "rebase",
        },
        show_cherry_pick and Section {
          -- TODO Picking (sequencer - cherry_pick_head)
        },
        show_revert and Section {
          title = SectionTitle { title = "Reverting" },
          render = SectionItemRevert,
          items = state.sequencer.items,
          folded = config.sections.sequencer.folded,
          name = "revert"
        },
        show_untracked and Section {
          -- TODO: Group untracked by directory and create a fold
          title = SectionTitle { title = "Untracked files" },
          render = SectionItemFile,
          items = state.untracked.items,
          folded = config.sections.untracked.folded,
          name = "untracked",
        },
        show_unstaged and Section {
          title = SectionTitle { title = "Unstaged changes" },
          render = SectionItemFile,
          items = state.unstaged.items,
          folded = config.sections.unstaged.folded,
          name = "unstaged",
        },
        show_staged and Section {
          title = SectionTitle { title = "Staged changes" },
          render = SectionItemFile,
          items = state.staged.items,
          folded = config.sections.staged.folded,
          name = "staged",
        },
        show_upstream_unpulled and Section {
          title = SectionTitleRemote { title = "Unpulled from", ref = state.upstream.ref },
          render = SectionItemCommit,
          items = state.upstream.unpulled.items,
          folded = config.sections.unpulled_upstream.folded,
        },
        show_pushRemote_unpulled and Section {
          title = SectionTitleRemote { title = "Unpulled from", ref = state.pushRemote.ref },
          render = SectionItemCommit,
          items = state.pushRemote.unpulled.items,
          folded = config.sections.unpulled_pushRemote.folded,
        },
        show_upstream_unmerged and Section {
          title = SectionTitleRemote { title = "Unmerged into", ref = state.upstream.ref },
          render = SectionItemCommit,
          items = state.upstream.unmerged.items,
          folded = config.sections.unmerged_upstream.folded,
        },
        show_pushRemote_unmerged and Section {
          title = SectionTitleRemote { title = "Unpushed to", ref = state.pushRemote.ref },
          render = SectionItemCommit,
          items = state.pushRemote.unmerged.items,
          folded = config.sections.unmerged_pushRemote.folded,
        },
        show_stashes and Section {
          title = SectionTitle { title = "Stashes" },
          render = SectionItemStash,
          items = state.stashes.items,
          folded = config.sections.stashes.folded,
        },
        show_recent and Section {
          title = SectionTitle { title = "Recent Commits" },
          render = SectionItemCommit,
          items = state.recent.items,
          folded = config.sections.recent.folded,
        },
      },
    },
  }
end

return M
