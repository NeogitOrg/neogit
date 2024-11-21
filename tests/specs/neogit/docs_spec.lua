local Path = require("plenary.path")

describe("docs", function()
  it("doesn't repeat any tags", function()
    local docs = Path.new(vim.uv.cwd(), "doc", "neogit.txt")
    local tags = {}

    for line in docs:iter() do
      for tag in string.gmatch(line, "%*([%w_]*)%*") do
        assert.Nil(tags[tag])
        tags[tag] = tag
      end
    end
  end)

  it("doesn't reference any undefined tags", function()
    local docs = Path.new(vim.uv.cwd(), "doc", "neogit.txt")
    local tags = {}
    local refs = {}

    for line in docs:iter() do
      for tag in string.gmatch(line, "%*([%w_]*)%*") do
        tags[tag] = true
      end

      for ref in string.gmatch(line, "|([%w_]*)|") do
        table.insert(refs, ref)
      end
    end

    for _, ref in ipairs(refs) do
      if not tags[ref] then
        vim.print("Undefined tag referenced! " .. ref)
      end

      assert.True(tags[ref])
    end
  end)
end)
