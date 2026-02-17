{
  perSystem =
    { pkgs, ... }:
    let
      version = "0.1.0";

      seamless-navigation = pkgs.vimUtils.buildVimPlugin {
        name = "seamless-navigation";
        src = ../..;
        version = version;
      };
    in
    {
      packages = {
        default = seamless-navigation;
        seamless-navigation = seamless-navigation;
      };
    };
}
