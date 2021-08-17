require 'plenary.async'.tests.add_to_env()
local eq = assert.are.same
local operations = require'neogit.operations'
local harness = require'tests.git_harness'
local in_prepared_repo = harness.in_prepared_repo
local get_current_branch = harness.get_current_branch
--local status = require'neogit.status'

local input = require'tests.mocks.input'

local function act(normal_cmd)
  vim.cmd('normal '..normal_cmd)
end

describe('branch popup', function ()
  it('can switch to another branch in the repository', in_prepared_repo(function ()
    input.value = 'second-branch'
    act('bb')
    operations.wait('checkout_branch')
    eq('second-branch', get_current_branch())
  end))

  it('can switch to another local branch in the repository', in_prepared_repo(function ()
    input.value = 'second-branch'
    act('bl')
    operations.wait('checkout_local-branch')
    eq('second-branch', get_current_branch())
  end))

  it('can create a new branch', in_prepared_repo(function ()
    input.value = 'branch-from-test'
    act('bc')
    operations.wait('checkout_create-branch')
    eq('branch-from-test', get_current_branch())
  end))
end)

