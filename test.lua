local result = { "" }
local job = vim.fn.jobstart({ "cat", "tests/a.txt" }, {
  on_stdout = function(_, data)
    print("Got: ", vim.inspect(data))
    result[#result] = result[#result] .. data[1]
    for i = 2, #data do
      result[#result + 1] = data[i]
    end
  end,
})

vim.fn.jobwait({ job }, 2000)
