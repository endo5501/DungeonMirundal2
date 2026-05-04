#!/usr/bin/env bash
# scripts/run_tests.sh
#
# Test runner with two safety nets that prevent silent test failures from
# slipping past GUT's "All tests passed!" message:
#
#   1. Pre-flight: every .gd file under src/ and tests/ is parsed via
#      scripts/check_scripts.gd. Files that fail to parse halt the run before
#      GUT is even invoked.
#
#   2. Post-scan: GUT output is searched for patterns that indicate a script
#      was silently dropped from the test set, even when GUT itself returned 0:
#        - SCRIPT ERROR:                    (parser / load error)
#        - Failed to load script            (engine load failure)
#        - Ignoring script ... because it   (GUT misclassifying a parse-failed
#          does not extend GutTest             test as "not a GutTest")
#
# Any extra arguments are forwarded to gut_cmdln.gd (e.g. -gtest=...).
#
# Exit code: 0 if both phases pass, 1 otherwise.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PATTERNS='SCRIPT ERROR:|Failed to load script|Ignoring script .* because it does not extend GutTest'

echo "=== Phase 1/2: Pre-flight script parse check ==="
godot --headless -s scripts/check_scripts.gd
preflight_exit=$?
if [ $preflight_exit -ne 0 ]; then
    echo
    echo "[X] Pre-flight detected parse failures. Aborting before GUT."
    echo "    Fix the PARSE_FAIL paths above, then re-run."
    exit 1
fi

echo
echo "=== Phase 2/2: GUT test run ==="
tmplog=$(mktemp)
trap 'rm -f "$tmplog"' EXIT

godot --headless -s addons/gut/gut_cmdln.gd "$@" 2>&1 | tee "$tmplog"
gut_exit=${PIPESTATUS[0]}

echo
echo "=== Result ==="
if grep -Eq "$PATTERNS" "$tmplog"; then
    echo "[X] Detected silent test failure indicators in GUT output:"
    grep -E "$PATTERNS" "$tmplog" | sed 's/^/  /'
    echo
    echo "GUT reported exit code $gut_exit, but the patterns above mean some tests never ran."
    exit 1
fi

if [ $gut_exit -ne 0 ]; then
    echo "[X] GUT reported a non-zero exit code: $gut_exit"
    exit $gut_exit
fi

echo "[OK] All checks passed: pre-flight clean, GUT green, no silent failures."
exit 0
