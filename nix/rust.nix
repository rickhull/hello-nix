{ sources ? import ./sources.nix }:

let
  pkgs =
    import sources.nixpkgs {
      overlays = [ (import sources.nixpkgs-mozilla) ];
    };
  channel = "nightly";
  date = "2020-06-10";
  targets = [ ];
  chan = pkgs.rustChannelOfTargets channel date targets;
in chan
