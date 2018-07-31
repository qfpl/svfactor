{ nixpkgs, declInput }: let pkgs = import nixpkgs {}; in {
  jobsets = pkgs.runCommand "spec.json" {} ''
    cat <<EOF
    ${builtins.toXML declInput}
    EOF
    cat > $out <<EOF
    {
        "svfactor": {
            "enabled": 1,
            "hidden": false,
            "description": "svfactor",
            "nixexprinput": "svfactor",
            "nixexprpath": "./ci/ci.nix",
            "checkinterval": 300,
            "schedulingshares": 1,
            "enableemail": false,
            "emailoverride": "",
            "keepnr": 5,
            "inputs": {
                "svfactor": { "type": "git", "value": "https://github.com/qfpl/svfactor.git master", "emailresponsible": false },
                "nixpkgs": { "type": "git", "value": "https://github.com/NixOS/nixpkgs.git release-18.03", "emailresponsible": false }
            }
        }
    }
    EOF
  '';
}
