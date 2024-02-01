# Neogit Tests

## Running Tests

As a base requirement you must have `make` installed.

Once `make` is installed you can run tests by entering `make test` in the top level directory of Neogit into your command line.

## Adding a test dependency

If you're adding a lua plugin dependency to Neogit and wish to test it, open `tests/init.lua` in your editor.

Look for the following lines:

```lua
if os.getenv("CI") then
  vim.opt.runtimepath:prepend(vim.fn.getcwd())
  vim.cmd([[runtime! plugin/plenary.vim]])
  vim.cmd([[runtime! plugin/neogit.lua]])
else
  ensure_installed("nvim-lua/plenary.nvim")
  ensure_installed("nvim-telescope/telescope.nvim")
end
```

As an example let's say we want to add [`vim-fugitive`](https://github.com/tpope/vim-fugitive) to our test dependencies. Our new dependency section would look like this:

```lua
if os.getenv("CI") then
  vim.opt.runtimepath:prepend(vim.fn.getcwd())
  vim.cmd([[runtime! plugin/plenary.vim]])
  vim.cmd([[runtime! plugin/neogit.lua]])
  vim.cmd([[runtime! plugin/fugitive.vim]])
else
  ensure_installed("nvim-lua/plenary.nvim")
  ensure_installed("nvim-telescope/telescope.nvim")
  ensure_installed("tpope/vim-fugitive")
end
```

## Test Organization

### Where do tests go?

All tests are to be placed within the `tests/specs` directory, and placed mocking the path of the Neogit module the test is responsible for. For instance, say you wanted to test `lua/neogit/config.lua` then you would create the test file in `tests/specs/neogit/config_spec.lua` which mirrors the path in the main Neogit module.

### Where do utility functions go?

If you have any utility code that has to do with git, it should be placed in `tests/util/git_harness.lua`.

If you have a generic utility function _only_ relevant for tests then it should go in `tests/util/util.lua`. If it is generic enough that it could be useful in the general Neogit code then a consideration should be made to place this utility code in `lua/neogit/lib/util.lua`.

### Where should raw content files go?

Raw content files that you want to test against should go into `tests/fixtures`. If you have a raw file you'd like to use against in git, then you'll need to add it to the git repository within `tests/.repo`. This can be done by changing directory into `tests/.repo` and renaming `.git.orig` to `.git` then adding any relevant changes to that repository. Once you're done, make sure you rename `.git` back to `.git.org`.

As a note the above is likely to become deprecated when a improved declarative lua git repository creation is made.

## Writing a test

Let's write a basic test to validate two things about a variable to get a quick intro to writing tests.

1. Validate the variable's type
2. Validate the variable's content

```lua
local our_variable = "Hello World!"
describe("validating a string variable", function ()
  it("should be of type string", function()
    assert.True(type(our_variable) == "string")
  end)

  it("should have content 'Hello World!'", function()
     assert.are.same("Hello World!", our_variable)
  )
end)
```

Nothing too crazy there.

Now let's take a look at a test for Neogit, specifically our `tests/specs/neogit/lib/git/cli_spec.lua` test.

```lua
local eq = assert.are.same
local git_cli = require("neogit.lib.git.cli")
local git_harness = require("tests.util.git_harness")
local in_prepared_repo = git_harness.in_prepared_repo

describe("git cli", function()
  describe("root detection", function()
    it(
      "finds the correct git root for a non symlinked directory",
      in_prepared_repo(function(root_dir)
        local detected_root_dir = git_cli.git_root_of_cwd()
        eq(detected_root_dir, root_dir)
      end)
    )
  end)
end)
```

This test gets the root directory of a git repository. You'll notice something interesting we do in our `it` statement different from the prior example. We're passing `in_prepared_repo` to `it`. This function sets up a simple test bed repository (specifically the repository found with `tests/.repo`) to test Neogit against. If you ever need to test Neogit in a way that requires a git repository, you probably want to use `in_prepared_repo`.

For more test examples take a look at the tests written within the `tests` directory or our test runner's testing guide: [plenary test guide](https://github.com/nvim-lua/plenary.nvim/blob/master/TESTS_README.md).

For the assertions available, most assertions from [`luassert`](https://github.com/lunarmodules/luassert) are accessible.
