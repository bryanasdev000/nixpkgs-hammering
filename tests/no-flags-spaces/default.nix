{ callPackage
}:

{
  # positive cases
  bad = callPackage ./bad.nix { };

  # negative cases
  okay = callPackage ./okay.nix { };
}
