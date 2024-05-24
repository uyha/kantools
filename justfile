set positional-arguments

gen-lsp:
  #!/usr/bin/env bash

  if ! [[ -d /tmp/zig-lsp-codegen ]]; then
    git clone https://github.com/zigtools/zig-lsp-codegen.git /tmp/zig-lsp-codegen
  fi
  cd /tmp/zig-lsp-codegen
  curl -LJ https://github.com/microsoft/vscode-languageserver-node/raw/main/protocol/metaModel.json -o /tmp/zig-lsp-codegen/metaModel.json
  zig build
  mv zig-out/artifacts/lsp.zig {{justfile_directory()}}/src/
  cd
  rm -rf /tmp/zig-lsp-codegen
