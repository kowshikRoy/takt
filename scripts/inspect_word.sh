#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:$HOME/development/flutter/bin:$HOME/flutter/bin:$PATH"

if [ -z "$1" ]; then
  echo "Usage: ./scripts/inspect_word.sh <word>"
  exit 1
fi

WORD="$1" flutter test test/inspect_word_test.dart
