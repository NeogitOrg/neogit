# Contributing

Contributions of all kinds are very welcome. If you are planning to implement a larger feature please open an issue
prior to minimize the risk of duplicate work, or to discuss some specifics of the feature; such as keybindings.

Neogit draws heavy inspiration from [Magit](https://magit.vc/), but aims to be its own thing. Many of our features
are inspired by Magit, such as the branch keybindings.


## Architecture

- [`./lua/neogit/`]
  - [`./lua/neogit/lib/`] Contains various git and filesystem abstractions
  - [`./lua/neogit/lib/git/`] High level git wrappers for common commands such as branches, fetch. These are also used
  to supply the status buffer
  - [`./lua/neogit/lib/git/cli.lua`] Builder like pattern for constructing git cli invocations
  - [`./lua/neogit/lib/git/repository.lua`] Modules from `git/` for updating the status buffer
  - [`./lua/neogit/popups/`] Contains all the popups and keybindings
  - [`./lua/neogit/buffers/`] Contains all the buffer views, such as `commit_editor` or `log_view`

`Neogit` uses its own UI drawing library for drawing columns and rows of text.

### Making a new view

Neogit's views, such as the `commit` buffer, `log` graph buffer, etc are located in [`./lua/neogit/buffers/`]. They
are split in a `init.lua` for creating the buffer and setting up keymaps and actions, and `ui.lua` for rendering the
buffer. The split is such that it is easier to get an overview of how the buffer will *look* without the clutter of git
commands and actions.

Opening a view is typically done through a *popup* which allows you to configure options before invoking the view.

These reside inside [`./lua/neogit/popups/`], and are split into `init.lua` and `actions.lua` for the setup and
keybindings, and the git commands to execute, likewise intended to get an overview of the options and keybindings for
the popup in `init.lua` without concerning yourself with the git commands and parsing in `actions.lua`.

To access your new popup through a keybinding, add it to the table in [`./lua/neogit/popups/init.lua`] inside
`mappings_table`. This will enable you to access the popup through both the status buffer and help popup.

## Getting Started

If you are using [`Lazy.nvim`](https://github.com/folke/lazy.nvim) you can configure it to prefer sourcing plugins from
a local directory instead of from git. 

Simply clone *Neogit* to your project directory of choice to be able to use your local changes. See
[`lazy-spec`](https://github.com/folke/lazy.nvim#-plugin-spec) and
[`lazy-configuration`](https://github.com/folke/lazy.nvim#%EF%B8%8F-configuration) for details.

### Logging

Logging is a useful tool for inspecting what happens in the code and in what order. Neogit uses
[`Plenary`](https://github.com/nvim-lua/plenary.nvim) for logging.

Export the environment variables `NEOGIT_LOG_CONSOLE="sync"` to enable logging, and `NEOGIT_LOG_LEVEL="debug"` for more
verbose logging.


```lua
local logger = require("neogit.logger")

logger.info("This is a log message")
logger.debug(("This is a verbose log message: %q"):format(str_to_quote))
logger.debug(("This is a verbose log message: %s"):format(vim.inspect(thing)))
```

If suitable, prefer to scope your logs using `[ SCOPE ]` to make it easier to find the source of a message, such as:

`[ Status ]: not staging item in %s`,

rather than:

`Not staging item %s`.

## Code Standards

### Testing

Neogit is tested using [`Plenary`](https://github.com/nvim-lua/plenary.nvim#plenarytest_harness) for unit tests, and `rspec` (yes, ruby) for e2e tests.

It uses a *Busted* style testing, where each lua file inside [`./tests/specs/{test_name}_spec.lua`] is run.

Plenary uses it's own port of busted and a bundled luassert, so consult their
code and the respective [busted](http://olivinelabs.com/busted/) and
[luassert](http://olivinelabs.com/busted/#asserts) docs for what methods are
available.

When adding new functionality we strongly encourage you to add a test spec to ensure that the feature works and remains
working when new functionality is tacked on.

If you find or fix a bug, it is desired that you add a test case for the bug to ensure it does not occur again in the
future, and remains *fixed*.

A [`Makefile`](./Makefile) is set up to run tests.

```sh
make test
```
See [the test documentation for more details](./tests/README.md).

### Linting

Additionally, linting is enforced using `selene` to catch common errors, most of which are also caught by
`lua-language-server`. Source code spell checking is done via `typos`.

```sh
make lint
```

### Formatting

`stylua` is used for formatting. This formatting is slightly different from the built in formatting for
`lua-language-server`.
