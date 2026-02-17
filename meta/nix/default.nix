{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.partitions
    ./nixvimmodules.nix
    ./packages.nix
  ];

  partitions = {
    # Define the dev partition, which will be used to define things like
    # dev shell and formatting. The actual Neovim plugin is not
    # in this partition.
    dev = {
      module = ./dev;
      extraInputsFlake = ./dev;
    };
  };

  partitionedAttrs = {
    checks = "dev";
    devShells = "dev";
    formatter = "dev";
  };
}
