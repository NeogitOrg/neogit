local function parse(output)
  local result = {}
  for _, line in ipairs(output) do
    local stash_num, stash_desc = line:match('stash@{(%d*)}: (.*)')
    table.insert(result, { idx = tonumber(stash_num), name = stash_desc})
  end
  return result
end

return {
  parse = parse
}
