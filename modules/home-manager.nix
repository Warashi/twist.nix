# home-manager module that provides an installation of Emacs
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    mkOptionType
    types
    ;
  cfg = config.programs.emacs-twist;

  emacs-config = cfg.config;

  initFile = pkgs.runCommandLocal "init.el" { } ''
    mkdir -p $out
    touch $out/init.el
    for file in ${builtins.concatStringsSep " " emacs-config.initFiles}
    do
      cat "$file" >> $out/init.el
      echo >> $out/init.el
    done
  '';

  wrapper =
    pkgs.runCommandLocal cfg.name
      {
        propagatedBuildInputs = [
          emacs-config
        ];
        nativeBuildInputs = [
          pkgs.makeWrapper
        ];
      }
      ''
        mkdir -p $out/bin

        makeWrapper ${emacs-config}/bin/emacs $out/bin/${cfg.name} \
          --add-flags --init-directory="${config.home.homeDirectory}/${cfg.directory}"

        ${lib.optionalString cfg.emacsclient.enable "ln -t $out/bin -s ${emacs-config.emacs}/bin/emacsclient"}
      '';

  appBundleName =
    (lib.strings.toUpper (builtins.substring 0 1 cfg.name)) + (builtins.substring 1 (-1) cfg.name);

  # The bundle lives in its own derivation, apart from the wrapper, so that it
  # can be installed by other means (e.g. signed with a stable identity) without
  # a second Applications/<Name>.app competing for the same path in
  # home.packages.
  appBundle = pkgs.runCommandLocal "${cfg.name}-app" { } ''
    mkdir -p $out
    if [[ -d "${emacs-config}/Applications/Emacs.app" ]]; then
      mkdir -p $out/Applications
      cp -r ${emacs-config}/Applications/Emacs.app $out/Applications/${appBundleName}.app
    fi
  '';

  desktopItem = pkgs.makeDesktopItem {
    inherit (cfg) name;
    inherit (cfg.desktopItem) desktopName mimeTypes;
    comment = "Edit text";
    genericName = "Text Editor";
    exec = "${cfg.name} %F";
    icon = "emacs";
    startupNotify = true;
    startupWMClass = "Emacs";
    categories = [
      "TextEditor"
      "Development"
    ];
  };
in
{
  options = {
    programs.emacs-twist = {
      enable = mkEnableOption "Emacs Twist";

      name = mkOption {
        type = types.str;
        description = "Name of the wrapper script";
        default = "emacs";
        example = "my-emacs";
      };

      directory = mkOption {
        type = types.str;
        description = "Relative path in string to user-emacs-directory from the home directory";
        default = ".config/emacs";
        example = ".local/share/emacs";
      };

      createInitFile = mkOption {
        type = types.bool;
        description = "Whether to create init.el in the directory";
        default = false;
      };

      earlyInitFile = mkOption {
        type = types.nullOr types.path;
        description = ''
          Path to early-init.el.

          If the value is nil, no file is created in the directory.
        '';
        default = null;
      };

      createManifestFile = mkOption {
        type = types.bool;
        description = "Whether to create the manifest file in the directory";
        default = false;
      };

      manifestFileName = mkOption {
        type = types.str;
        description = ''
          Name of the manifest file, relative from `user-emacs-directory`.

          This is necessary to enable hot reloading of packages.
        '';
        default = "twist-manifest.json";
      };

      config = mkOption {
        type = mkOptionType {
          name = "twist";
          description = "Configuration of emacs-twist";
          check = c: c ? initFiles && c ? emacs;
        };
      };

      wrapper = mkOption {
        type = types.package;
        description = "The wrapper derivation";
        readOnly = true;
        default = wrapper;
      };

      appBundle = {
        enable = mkOption {
          type = types.bool;
          description = ''
            Whether to install the macOS application bundle
            (`Applications/<Name>.app`) through `home.packages`.

            Disable this to install {option}`programs.emacs-twist.appBundle.package`
            by other means, e.g. after signing it with a stable identity.
          '';
          default = pkgs.stdenv.hostPlatform.isDarwin;
          defaultText = lib.literalExpression "pkgs.stdenv.hostPlatform.isDarwin";
        };

        package = mkOption {
          type = types.package;
          description = ''
            Derivation holding only the macOS application bundle.

            Unlike the wrapper script, the bundle starts Emacs without
            `--init-directory`, so {option}`programs.emacs-twist.directory`
            only takes effect when Emacs would find it by itself, i.e. the
            XDG default `.config/emacs` with no `~/.emacs.d`.
          '';
          readOnly = true;
          default = appBundle;
        };
      };

      emacsclient = {
        enable = mkOption {
          type = types.bool;
          description = "Whether to install emacsclient";
        };
      };

      serviceIntegration = {
        enable = mkEnableOption ''
          Enable service integration. For now, only systemd is supported.
        '';
      };

      icons = {
        enable = mkOption {
          type = types.bool;
          description = "Whether to install Emacs icons";
          default = true;
        };
      };

      desktopItem = {
        desktopName = mkOption {
          type = types.str;
          description = "Long name of the desktop item";
          default = "Emacs";
        };

        mimeTypes = mkOption {
          type = types.listOf types.str;
          description = "List of mime types associated with the wrapper";
          default = [
            "text/plain"
            "inode/directory"
          ];
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = lib.optional (pkgs.stdenv.hostPlatform.isDarwin && cfg.directory != ".config/emacs") (
      "programs.emacs-twist: ${appBundleName}.app cannot pass --init-directory, "
      + "so Emacs started from the bundle ignores `directory` (${cfg.directory})."
    );

    home.packages = [
      wrapper
    ]
    ++ lib.optional cfg.appBundle.enable appBundle
    ++ lib.optional cfg.icons.enable emacs-config.icons
    ++ lib.optional (!pkgs.stdenv.hostPlatform.isDarwin) (
      pkgs.runCommandLocal "${cfg.name}-desktop-item"
        {
          nativeBuildInputs = [ pkgs.copyDesktopItems ];
          desktopItems = desktopItem;
        }
        ''
          runHook postInstall
        ''
    );

    home.file = builtins.listToAttrs (
      (lib.optional cfg.createInitFile {
        name = "${cfg.directory}/init.el";
        value = {
          source = "${initFile}/init.el";
        };
      })
      ++ (lib.optional (cfg.earlyInitFile != null) {
        name = "${cfg.directory}/early-init.el";
        value = {
          source = cfg.earlyInitFile;
        };
      })
      ++ (lib.optional (cfg.createManifestFile && emacs-config.emacsWrapper.elispManifestPath != null) {
        name = "${cfg.directory}/${cfg.manifestFileName}";
        value = {
          source = emacs-config.emacsWrapper.elispManifestPath;
        };
      })
    );

    services.emacs = lib.mkIf cfg.serviceIntegration.enable {
      enable = true;
      package = wrapper;
    };
  };
}
