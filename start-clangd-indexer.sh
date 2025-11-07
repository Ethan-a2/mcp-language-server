#!/usr/bin/env bash

set -ex

function terminate {
  kill -9 "${CLANGD_PID:-}"
  rm -f /tmp/clangd-input
  rm -f clangd.log
}

trap terminate EXIT

__stdin="/tmp/clangd-input"
rm -f ${__stdin} || true
mkfifo ${__stdin}

tail -f ${__stdin} | /usr/local/bin/clangd \
  --log=verbose \
  --compile-commands-dir=/src_root \
  --background-index \
  --all-scopes-completion \
  --clang-tidy \
  --clang-tidy-checks=modernize-*,misc-* \
  --header-insertion=iwyu \
  --suggest-missing-includes \
  > clangd.log 2>&1 &

CLANGD_PID=$!

echo "Waiting for clangd (${CLANGD_PID}) server to start..."
sleep 5
echo "Sending LSP input to clangd server..."
echo "" > ${__stdin} # initializing stdin
cat input.clangd.txt > ${__stdin}

echo "Waiting for clangd (${CLANGD_PID}) background indexer to complete..."
( tail -f -n0 clangd.log & ) | grep -qP "BackgroundIndex: building version .* when background indexer is idle"

echo "Done"

exit 0
