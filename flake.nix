{
  description = "T3 Code desktop app, packaged from the upstream AppImage";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      release = builtins.fromJSON (builtins.readFile ./sources.json);
      inherit (release) version;

      sources =
        builtins.mapAttrs
          (_: arch: {
            inherit arch;
            hash = release.hashes.${arch};
          })
          {
            x86_64-linux = "x86_64";
            aarch64-linux = "arm64";
          };

      forAllSystems = nixpkgs.lib.genAttrs (builtins.attrNames sources);

      mkT3code =
        pkgs:
        let
          inherit (pkgs) lib appimageTools fetchurl;
          pname = "t3code";
          source = sources.${pkgs.stdenv.hostPlatform.system};

          src = fetchurl {
            url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-${source.arch}.AppImage";
            inherit (source) hash;
          };

          contents = appimageTools.extract { inherit pname version src; };
        in
        appimageTools.wrapType2 {
          inherit pname version src;

          extraPkgs = pkgs: [ pkgs.libsecret ];

          extraInstallCommands = ''
            install -Dm444 ${contents}/t3code.desktop $out/share/applications/t3code.desktop
            substituteInPlace $out/share/applications/t3code.desktop \
              --replace-fail 'Exec=AppRun %U' 'Exec=t3code %U'
            cp -r ${contents}/usr/share/icons $out/share/
          '';

          meta = {
            description = "Minimal web GUI for coding agents";
            homepage = "https://t3.codes";
            changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
            license = lib.licenses.mit;
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            mainProgram = "t3code";
            platforms = builtins.attrNames sources;
          };
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          t3code = mkT3code nixpkgs.legacyPackages.${system};
        in
        {
          inherit t3code;
          default = t3code;
        }
      );

      overlays.default = final: _prev: {
        t3code = mkT3code final;
      };
    };
}
