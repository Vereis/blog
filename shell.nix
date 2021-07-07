{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.elixir_1_11
    pkgs.nodejs-10_x
    pkgs.inotify-tools
  ];

  shellHook = ''
    unset ERL_LIBS

    export DB_PORT="1234"
    export DB_NAME="blog"
    export DB_USER="postgres"
    export DB_PASSWORD="postgres"
  '';
}
