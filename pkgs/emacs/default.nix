{ lib
, pkgs
}:
{ emacs ? pkgs.emacs
, lockFile
, inventorySpecs
, initFiles
, extraPackages ? [ "use-package" ]
, addSystemPackages ? true
, inputOverrides ? { }
, nativeCompileAheadDefault ? true
}:
let
  inherit (builtins) readFile attrNames attrValues concatLists isFunction
    split filter isString mapAttrs;

  profileElisp = { passthru, ... }: lib.pipe passthru.elispAttrs [
    (lib.filterAttrs (_: v: ! isFunction v))
  ];
in
lib.makeScope pkgs.newScope (self:
  let
    userConfig = lib.pipe self.initFiles [
      (map (file: lib.parseUsePackages (readFile file)))
      lib.zipAttrs
      (lib.mapAttrs (_: concatLists))
    ];

    explicitPackages = userConfig.elispPackages ++ extraPackages;

    builtinLibraryList = self.callPackage ./builtins.nix { };

    builtinLibraries = lib.pipe (readFile builtinLibraryList) [
      (split "\n")
      (filter (s: isString s && s != ""))
    ];

    enumerateConcretePackageSet = import ./data {
      inherit lib emacs lockFile
        builtinLibraries inventorySpecs inputOverrides;
    };

    packageInputs = enumerateConcretePackageSet explicitPackages;

    visibleBuiltinLibraries = lib.subtractLists explicitPackages builtinLibraries;

    allDependencies = lib.fix (self:
      mapAttrs
        (ename: { packageRequires, ... } @ attrs:
          let
            explicitDeps = lib.subtractLists visibleBuiltinLibraries packageRequires;
          in
            lib.unique
              (explicitDeps
               ++ concatLists (lib.attrVals explicitDeps self)))
        packageInputs);
in
  {
    inherit lib emacs;

    # Expose only for convenience.
    inherit initFiles;

    # Expose for inspecting the configuration. Don't override this attribute
    # using overrideScope', it doesn't affect anything.
    packageInputs = lib.pipe packageInputs [
      (mapAttrs (_: lib.filterAttrs (_: v: ! isFunction v)))
    ];

    # You cannot use callPackageWith because it will apply makeOverridable
    # which will add extra attributes, e.g. overrideDerivation, to the result.
    # It will make builtins.attrNames unusable to this attribute.
    elispPackages = lib.makeScope self.newScope (eself:
      mapAttrs
        (ename: attrs:
          self.callPackage ./build-elisp.nix { }
            ({
              nativeCompileAhead = nativeCompileAheadDefault;
              elispInputs = lib.attrVals allDependencies.${ename} eself;
            } // attrs))
        packageInputs);

    emacsWrapper = self.callPackage ./wrapper.nix
      {
        elispInputs = lib.attrVals (attrNames packageInputs) self.elispPackages;
        # It may be better to use lib.attrByPath to access packages like
        # gitAndTools.git-lfs, but I am not sure if a path can be safely
        # split by ".".
        executablePackages =
          if addSystemPackages
          then lib.attrVals userConfig.systemPackages pkgs
          else [ ];
      };

    # This makes the attrset a derivation for a shorthand.
    inherit (self.emacsWrapper) name type outputName outPath drvPath;

    flakeNix = {
      description = "This is an auto-generated file. Please don't edit it manually.";
      inputs =
        lib.mapAttrs
          (_: { origin, ... }: origin // { flake = false; })
          packageInputs;
      outputs = { ... }: {};
    };

    flakeLock = import ./lock.nix {
      inherit lib lockFile;
      inherit (self) elispPackages;
    };
  })
