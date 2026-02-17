{ inputs, ... }:
{
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem =
    {
      ...
    }:
    {
      treefmt = {
        programs = {
          nixfmt.enable = true;
          prettier.enable = true;
          stylua.enable = true;
        };

        settings.formatter.prettier.includes = [
          ".prettierrc"
          "**/flake.lock"
          "flake.lock"
        ];

        settings.excludes = [
          ".editorconfig"
          ".github/CODEOWNERS"
          ".gitignore"
          ".prettierignore"
          "LICENSE"
        ];
      };
    };
}
