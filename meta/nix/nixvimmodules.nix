{ inputs, ... }:
{
  flake.nixvimModules.default =
    {
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.nixvim) defaultNullOpts;
      pkg = inputs.self.packages.${pkgs.system}.default;
    in
    lib.nixvim.plugins.mkNeovimPlugin {
      name = "seamless-navigation";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkg;
        description = "seamless navigation plugin package";
      };
      maintainers = [ "coletrammer" ];
      settingsOptions = {
        handle_enter = defaultNullOpts.mkBool true ''
          Handle seamless navigation enter events. If enabled, navigating into Neovim will adjust the active window to the one closest to where the navigation came from.
        '';
        wrap_internal_navigation = defaultNullOpts.mkBool true ''
          Wrap around when navigating in a direction no panes are available, instead of doing nothing.
        '';
        hide_cursor_on_enter = defaultNullOpts.mkBool true ''
          When handling an enter event, temporarily hide the cursor until the enter event is processed. This prevents the cursor from flickering.
        '';
        debug = defaultNullOpts.mkBool false ''
          Enable debug logging.
        '';
        log_file = lib.nixvim.mkNullOrStr ''
          Path to log debug information to.
        '';
      };
      settingsExample = {
        handle_enter = true;
        wrap_internal_navigation = true;
        hide_cursor_on_enter = true;
      };
    };
}
