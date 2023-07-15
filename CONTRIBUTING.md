# Contributing

Contributions and Pull Requests are very welcome. If you are planning to implement a larger feature please open an issue
prior to minimize the risk of multiple people working on the same thing simultaneously; or to discuss some specifics of
the feature.

Neogit draws heavy inspiration from [Magit](https://magit.vc/), but aims to be its own thing. Many of our features are
inspired by Magit, such as the branch keybindings.


## Architecture

- [`./lua/neogit/`]
  - [`./lua/neogit/lib/`] Contains various git and filesystem abstractions
  - [`./lua/neogit/lib/git/`] High level git wrappers for common commands such as branches, fetch. These are also used to
    supply the status buffer
  - [`./lua/neogit/lib/git/cli.lua`] Builder like pattern for constructing git cli invocations
  - [`./lua/neogit/lib/git/repository.lua`] Modules from `git/` for updating the status buffer
  - [`./lua/neogit.lua`]

Neogit uses its own UI drawing library for drawing columns and rows of text.

### Making a new view

Neogit's views, such as the `commit` buffer, `log` graph buffer, etc are located in [`./lua/neogit/buffers/`]. They
are split in a `init.lua` for creating the buffer and setting up keymaps and actions, and `ui.lua` for rendering the
buffer. The split is such that it is easier to get an overview of how the buffer will *look* without the clutter of git
commands and actions.

Opening a view is typically done through a *popup* which allows you to configure options before invoking the view.

These reside inside [`./lua/neogit/popups/`], and are split into `init.lua` and `actions.lua` for the setup and keybindings, and the git commands to execute, likewise intended to get an overview of the options and keybindings for the popup in `init.lua` without concerning yourself with the git commands and parsing in `actions.lua`.

## Code Standards

### Testing

Neogit is tested using [Plenary](https://github.com/nvim-lua/plenary.nvim#plenarytest_harness).

A [Makefile](./Makefile) is set up to run tests.

```sh
make test
```

### Linting

Additionally, linting is enforced using `selene` to catch common errors, most of which are also caught by
`lua-language-server`.

```sh
make lint
```

### Formatting

`stylua` is used for formatting. This formatting is slightly different from the built in formatting for
`lua-language-server`.
