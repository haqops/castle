{ config, lib, pkgs, ... }: let
  cfg          = config.castle.services.rapid-mlx;
  serviceUser  = "_castle-rapid-mlx";
  serviceHome  = "/var/lib/castle-rapid-mlx";
  venvPath     = "${serviceHome}/venv";
  python       = pkgs.python312;
in {
  options.castle.services.rapid-mlx = {
    enable = lib.mkEnableOption "Rapid-MLX local LLM server (OpenAI-compatible)";

    uid = lib.mkOption {
      type    = lib.types.int;
      default = 800;
      description = ''
        UID for the dedicated service account. nix-darwin doesn't auto-
        assign — pick something that doesn't collide with SetupAssistant
        humans (501+) or your castle.agents.
      '';
    };

    model = lib.mkOption {
      type    = lib.types.str;
      default = "gpt-oss-20b-mxfp4-q8";
      description = ''
        Model alias to serve. Run `sudo -u _castle-rapid-mlx
        /var/lib/castle-rapid-mlx/venv/bin/rapid-mlx models` after
        activation to see the catalog.
      '';
    };

    pipSpec = lib.mkOption {
      type    = lib.types.str;
      default = "rapid-mlx";
      example = "rapid-mlx==0.2.0";
      description = ''
        Argument passed to `pip install`. Pin a version via
        `rapid-mlx==X.Y.Z` if you don't want autoUpgrade.
      '';
    };

    autoUpgrade = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = ''
        If true, every activation runs `pip install --upgrade` for
        pipSpec — the venv always tracks whatever pip resolves.
        If false (default), first activation installs, subsequent
        activations skip the pip call for a fast switch.
      '';
    };

    extraArgs = lib.mkOption {
      type    = lib.types.listOf lib.types.str;
      default = [];
      example = [ "--port" "9000" ];
      description = ''
        Extra flags appended to `rapid-mlx serve <model>`. Rapid-MLX
        defaults to 127.0.0.1:8000 without arguments.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Dedicated system account — isolated from any human/agent macOS user.
    users.knownUsers = [ serviceUser ];
    users.users.${serviceUser} = {
      uid         = cfg.uid;
      home        = serviceHome;
      shell       = "/usr/bin/false";
      description = "castle rapid-mlx service";
    };

    # Home dir + venv managed on activation. pip lives in a service-owned
    # tree; no writes to /opt/homebrew, no writes to any human's ~/.
    system.activationScripts.postActivation.text = ''
      mkdir -p ${serviceHome}
      chown ${serviceUser}:staff ${serviceHome}
      chmod 755 ${serviceHome}

      if [ ! -x "${venvPath}/bin/rapid-mlx" ]; then
        echo "castle.services.rapid-mlx: creating venv at ${venvPath}"
        sudo -u ${serviceUser} -H ${python}/bin/python -m venv "${venvPath}"
        echo "castle.services.rapid-mlx: pip install ${cfg.pipSpec}"
        sudo -u ${serviceUser} -H "${venvPath}/bin/pip" install "${cfg.pipSpec}"
      ${lib.optionalString cfg.autoUpgrade ''
      else
        echo "castle.services.rapid-mlx: pip install --upgrade ${cfg.pipSpec}"
        sudo -u ${serviceUser} -H "${venvPath}/bin/pip" install --upgrade "${cfg.pipSpec}"
      ''}
      fi
    '';

    launchd.daemons.rapid-mlx = {
      serviceConfig = {
        Label            = "sh.castle.rapid-mlx";
        ProgramArguments = [ "${venvPath}/bin/rapid-mlx" "serve" cfg.model ] ++ cfg.extraArgs;
        UserName         = serviceUser;
        KeepAlive        = true;
        RunAtLoad        = true;
        StandardOutPath  = "${serviceHome}/serve.log";
        StandardErrorPath = "${serviceHome}/serve.err";
        EnvironmentVariables = {
          HOME = serviceHome;
          PATH = "${venvPath}/bin:/usr/bin:/bin";
        };
      };
    };
  };
}
