let
  sharedKeyboards = import ../../modules/shared/keyboards.nix;

  defaultKeyboard = "builtin";

  builtInKeyboards = {
    builtin = {
      name = "ThinkPad built-in keyboard";
      hyprlandDeviceNames = [ "at-translated-set-2-keyboard" ];
      xkb = {
        model = "pc105";
        layout = "gb";
        variant = "";
        options = "";
      };
    };
  };

  selectedExternalKeyboards = {
    inherit (sharedKeyboards) duckyKeyboard;
  };

  keyboards = builtInKeyboards // selectedExternalKeyboards;

  mkHyprlandDevices = keyboard:
    map
      (hyprlandDevice: {
        inherit hyprlandDevice;
        inherit (keyboard) name xkb;
      })
      keyboard.hyprlandDeviceNames;
in

{
  consoleKeyMap = "uk";

  inherit defaultKeyboard keyboards;

  defaultXkb = keyboards.${defaultKeyboard}.xkb;

  hyprlandDevices = builtins.concatLists (map mkHyprlandDevices (builtins.attrValues keyboards));
}
