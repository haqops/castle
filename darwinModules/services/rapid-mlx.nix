{ config, lib, ... }: let
  cfg = config.castle.services.rapid-mlx;
  # Dedicated macOS system user for the daemon. Isolated so it doesn't
  # touch anyone's real ~/. Model cache lives entirely under home.
  serviceUser = "_castle-rapid-mlx";
  serviceHome = "/var/lib/castle-rapid-mlx";
in {
  options.castle.services.rapid-mlx = {
    enable = lib.mkEnableOption "Rapid-MLX local LLM server (OpenAI-compatible)";

    executable = lib.mkOption {
      type = lib.types.str;
      default = "/opt/homebrew/bin/rapid-mlx";
      description = ''
        Absolute path to the rapid-mlx binary. Default assumes a
        Homebrew install on Apple Silicon.
      '';
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 800;
      description = ''
        UID for the dedicated service user. nix-darwin doesn't auto-
        assign — pick something above 500 that doesn't collide with
        macOS Setup Assistant humans (501+) or your castle.agents.
      '';
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "gpt-oss-20b-mxfp4-q8";
      description = ''
        Model alias to serve. Run `rapid-mlx models` on the Mac to see
        the catalog of aliases and their RAM requirements.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "--port" "9000" ];
      description = ''
        Extra flags appended to `rapid-mlx serve <model>`. Use this for
        `--port`, `--host`, or any other tunable — rapid-mlx defaults to
        127.0.0.1:8000 without arguments.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.knownUsers = [ serviceUser ];
    users.users.${serviceUser} = {
      uid         = cfg.uid;
      home        = serviceHome;
      shell       = "/usr/bin/false";
      description = "castle rapid-mlx service";
    };

    system.activationScripts.postActivation.text = ''
      # Home dir for the service; holds ~/.cache/huggingface with model files.
      mkdir -p ${serviceHome}
      chown -R ${serviceUser}:staff ${serviceHome} 2>/dev/null || true
      chmod 755 ${serviceHome}
    '';

    launchd.daemons.rapid-mlx = {
      serviceConfig = {
        Label            = "sh.castle.rapid-mlx";
        ProgramArguments = [ cfg.executable "serve" cfg.model ] ++ cfg.extraArgs;
        UserName         = serviceUser;
        KeepAlive        = true;
        RunAtLoad        = true;
        StandardOutPath  = "${serviceHome}/serve.log";
        StandardErrorPath = "${serviceHome}/serve.err";
        EnvironmentVariables = {
          HOME = serviceHome;
          PATH = "/opt/homebrew/bin:/usr/bin:/bin";
        };
      };
    };
  };
}
