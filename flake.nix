{
  description = "T3 Code desktop app, packaged from the upstream AppImage";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      releases = builtins.fromJSON (builtins.readFile ./sources.json);

      arches = {
        x86_64-linux = "x86_64";
        aarch64-linux = "arm64";
      };

      systems = builtins.attrNames arches;
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Builds one release channel ("stable" or "nightly") from its entry in sources.json.
      mkT3code =
        pkgs: channel:
        let
          inherit (pkgs) lib appimageTools fetchurl;
          inherit (releases.${channel}) version hashes;
          pname = if channel == "stable" then "t3code" else "t3code-${channel}";
          arch = arches.${pkgs.stdenv.hostPlatform.system};

          src = fetchurl {
            url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-${arch}.AppImage";
            hash = hashes.${arch};
          };

          contents = appimageTools.extract { inherit pname version src; };
        in
        appimageTools.wrapType2 {
          inherit pname version src;

          extraPkgs = pkgs: [ pkgs.libsecret ];

          extraInstallCommands = ''
            install -Dm444 ${contents}/t3code.desktop $out/share/applications/${pname}.desktop
            substituteInPlace $out/share/applications/${pname}.desktop \
              --replace-fail 'Exec=AppRun %U' 'Exec=${pname} %U'
            cp -r ${contents}/usr/share/icons $out/share/
          '';

          passthru = { inherit contents; };

          meta = {
            description = "Minimal web GUI for coding agents";
            homepage = "https://t3.codes";
            changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
            license = lib.licenses.mit;
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            mainProgram = pname;
            platforms = systems;
          };
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          t3code = mkT3code pkgs "stable";
          t3code-nightly = mkT3code pkgs "nightly";
          default = t3code;
        }
      );

      overlays.default = final: _prev: {
        t3code = mkT3code final "stable";
        t3code-nightly = mkT3code final "nightly";
      };
    };
}
