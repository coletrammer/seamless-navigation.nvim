{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        packages =
          # Treefmt and all individual formatters
          [ config.treefmt.build.wrapper ] ++ builtins.attrValues config.treefmt.build.programs;
      };
    };
}
