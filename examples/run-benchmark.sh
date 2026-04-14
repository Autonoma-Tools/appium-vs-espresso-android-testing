#!/usr/bin/env bash
# =============================================================================
# Example: Run the Appium vs Espresso benchmark and compare results
#
# This script demonstrates how to execute both benchmark suites and
# produce a side-by-side comparison.
#
# Prerequisites:
#   1. Android emulator running (Pixel 7 API 34 recommended):
#        emulator -avd Pixel_7_API_34
#
#   2. For Appium tests, start the Appium server:
#        appium --relaxed-security
#
#   3. Set your APK path for Appium tests:
#        export APPIUM_APP_PATH=/path/to/your/app-debug.apk
#
#   4. For Espresso tests, ensure your project path is set:
#        export ESPRESSO_PROJECT_DIR=/path/to/android-project
#
# Usage:
#   bash examples/run-benchmark.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BENCHMARK_SCRIPT="${REPO_ROOT}/benchmark/run.sh"

echo "================================================================"
echo "  Appium vs Espresso: 50-Test Android Benchmark"
echo "  Companion code for getautonoma.com/blog/appium-vs-espresso-android-testing"
echo "================================================================"
echo ""

# ---------------------------------------------------------------------------
# Option 1: Run just one framework
# ---------------------------------------------------------------------------
# Uncomment one of the following to run a single suite:
#
#   bash "${BENCHMARK_SCRIPT}" espresso
#   bash "${BENCHMARK_SCRIPT}" appium

# ---------------------------------------------------------------------------
# Option 2: Run both and compare (default)
# ---------------------------------------------------------------------------
echo "Running both frameworks and comparing results..."
echo ""

bash "${BENCHMARK_SCRIPT}" all

echo ""
echo "================================================================"
echo "  Benchmark complete."
echo "  Results saved to: benchmark/results/"
echo ""
echo "  Read the full analysis:"
echo "  https://getautonoma.com/blog/appium-vs-espresso-android-testing"
echo "================================================================"
