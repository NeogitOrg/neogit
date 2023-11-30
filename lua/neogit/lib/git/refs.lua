local cli = require("neogit.lib.git.cli")

local M = {}

--- Lists revisions
---@return table
function M.list()
  local revisions = cli["for-each-ref"].format('"%(refname:short)"').call():trim().stdout
  for i, str in ipairs(revisions) do
    revisions[i] = string.sub(str, 2, -2)
  end
  return revisions
end

local function json_format()
  local template = {
    [["head":"%(HEAD)"]],
    [["oid":"%(objectname)"]],
    [["ref":"%(refname)"]],
    [["name":"%(refname:short)"]],
    [["upstream_status":"%(upstream:trackshort)"]],
    [["upstream_name":"%(upstream:short)"]],
    [["subject":"%(subject)"]],
  }

  return string.format("{%s},", table.concat(template, ","))
end

local json = json_format()

function M.list_parsed()
  local refs = cli["for-each-ref"].format(json).call_sync():trim().stdout

  -- Wrap list of refs in an Array
  refs = "[" .. table.concat(refs, "\\n") .. "]"

  -- Remove trailing comma from last object in array
  refs, _ = refs:gsub(",]", "]")

  -- Remove escaped newlines from in-between objects
  refs, _ = refs:gsub("},\\n{", "},{")

  -- Escape any double-quote characters, or escape codes, in the subject
  refs, _ = refs:gsub([[(,"subject":")(.-)("})]], function(before, subject, after)
    return table.concat({ before, vim.fn.escape(subject, [[\"]]), after }, "")
  end)

  local ok, result = pcall(vim.json.decode, refs, { luanil = { object = true, array = true } })
  if not ok then
    assert(ok, "Failed to parse log json!: " .. result)
  end

  local output = {
    local_branch = {},
    remote_branch = {},
    tag = {},
  }

  for _, ref in ipairs(result) do
    ref.head = ref.head == "*"

    if ref.ref:match("^refs/heads/") then
      ref.type = "local_branch"
      table.insert(output.local_branch, ref)
    elseif ref.ref:match("^refs/remotes/") then
      local remote, branch = ref.ref:match("^refs/remotes/([^/]*)/(.*)$")
      if not output.remote_branch[remote] then
        output.remote_branch[remote] = {}
      end

      ref.type = "remote_branch"
      ref.name = branch
      table.insert(output.remote_branch[remote], ref)
    elseif ref.ref:match("^refs/tags/") then
      ref.type = "tag"
      table.insert(output.tag, ref)
    end
  end

  return output
end

return M
