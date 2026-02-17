# seamless-navigation.nvim

Neovim plugin which implements the seamless navigation protocol (OSC 8671).

## Features

This plugin provides a [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) like
experience for terminals which implement the seamless navigation protocol (OSC 8671).
This allows seamless navigation between Neovim windows and terminal panes using a single
set of key bindings. Since this is a terminal escape sequence protocol, other terminals
and multiplexer can implement. Although for the now the only implementation is [ttx](https://github.com/coletrammer/ttx).

As the protocol is entirely escape sequence driven, no key bindings are required on the
Neovim side. The pane navigation key bindings used by your terminal will automatically work
inside Neovim, once the plugin is setup.

This provides plugin also serves as a reference client implementation for terminal implementations
which choose to implement the seamless navigation protocol. More details on the protocol can be found
in the [ttx docs](https://coletrammer.github.io/ttx/osc__8671_8cpp.html).

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "coletrammer/seamless-navigation.nvim",
    opts = {
      -- These are default values.
      handle_enter = true,             -- Handle enter events
      wrap_internal_navigation = true, -- Wrap navigation requests internal to Neovim when requested
      hide_cursor_on_enter = true,     -- Hide cursor on enter events to prevent cursor flickering
    },
}
```

### [nixvim](https://nix-community.github.io/nixvim/)

Add this repository as a flake input:

```nix
{
  inputs = {
    seamless-navigation-nvim = {
      url = "github:coletrammer/seamless-navigation.nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  }
}
```

And then import the nixvim module and enable the plugin in your configuration:

```nix
{ inputs, ... }:
{
  imports = [ inputs.seamless-navigation-nvim.nixvimModules.default ];

  plugins.seamless-navigation = {
    enable = true;
    settings = {
      # Same configuration as with lazy
    };
  };
}
```

### [nix](https://nix.dev/)

As with above, consume this repository as a flake. Then add
`inputs.seamless-navigation-nvim.packages.${system}.default` to the Neovim
installation. And finally setup the flake via lua:

```lua
require("seamless-navigation").setup({})
```
