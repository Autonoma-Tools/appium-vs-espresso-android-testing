#!/usr/bin/env bash
# =============================================================================
# Espresso 50-Test Benchmark Suite
#
# Runs 50 representative Android UI tests using Espresso via Gradle.
#
# This script assumes:
#   - You have an Android project with Espresso tests in androidTest/
#   - A connected emulator or device (adb devices shows at least one)
#   - ANDROID_HOME or ANDROID_SDK_ROOT is set
#   - ./gradlew or gradle is available
#
# The tests exercise five categories (10 tests each):
#   1. View assertions    — verifying text, visibility, enabled state
#   2. Click interactions — tap buttons, FABs, menu items
#   3. Text input         — type into EditText, verify hints, clear fields
#   4. List scrolling     — RecyclerView scroll, item matching
#   5. Navigation         — intent verification, activity transitions
#
# Each test is executed individually to capture per-test timing.
# Output format per test: [PASS] | [FAIL] | [FLAKY] test_name (Xs)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ---------------------------------------------------------------------------
# Configuration — customize these to match your project
# ---------------------------------------------------------------------------
# Path to the Android project root (where build.gradle lives)
PROJECT_DIR="${ESPRESSO_PROJECT_DIR:-${REPO_ROOT}}"

# Gradle test command components
GRADLE_CMD="${PROJECT_DIR}/gradlew"
if [[ ! -x "${GRADLE_CMD}" ]]; then
  GRADLE_CMD="$(command -v gradle 2>/dev/null || echo "gradle")"
fi

MODULE="${ESPRESSO_MODULE:-app}"
TEST_RUNNER="androidx.test.runner.AndroidJUnitRunner"

# Retry count for flaky detection
FLAKY_RETRIES=1

# ---------------------------------------------------------------------------
# Test definitions: 50 tests across 5 categories
# Each entry: "fully.qualified.ClassName#methodName"
# Replace these with your actual Espresso test class/method names.
# ---------------------------------------------------------------------------
VIEW_ASSERTION_TESTS=(
  "com.example.benchmark.ViewAssertionTest#testHomeScreenTitleDisplayed"
  "com.example.benchmark.ViewAssertionTest#testSubtitleTextContent"
  "com.example.benchmark.ViewAssertionTest#testLogoImageVisible"
  "com.example.benchmark.ViewAssertionTest#testFooterVisible"
  "com.example.benchmark.ViewAssertionTest#testErrorMessageHidden"
  "com.example.benchmark.ViewAssertionTest#testButtonEnabled"
  "com.example.benchmark.ViewAssertionTest#testInputFieldHint"
  "com.example.benchmark.ViewAssertionTest#testToolbarTitle"
  "com.example.benchmark.ViewAssertionTest#testBadgeCountText"
  "com.example.benchmark.ViewAssertionTest#testEmptyStateMessage"
)

CLICK_INTERACTION_TESTS=(
  "com.example.benchmark.ClickInteractionTest#testPrimaryButtonClick"
  "com.example.benchmark.ClickInteractionTest#testFabClick"
  "com.example.benchmark.ClickInteractionTest#testMenuItemClick"
  "com.example.benchmark.ClickInteractionTest#testCheckboxToggle"
  "com.example.benchmark.ClickInteractionTest#testRadioButtonSelect"
  "com.example.benchmark.ClickInteractionTest#testSwitchToggle"
  "com.example.benchmark.ClickInteractionTest#testLongPress"
  "com.example.benchmark.ClickInteractionTest#testDoubleClick"
  "com.example.benchmark.ClickInteractionTest#testBackButtonPress"
  "com.example.benchmark.ClickInteractionTest#testDialogConfirm"
)

TEXT_INPUT_TESTS=(
  "com.example.benchmark.TextInputTest#testTypeUsername"
  "com.example.benchmark.TextInputTest#testTypePassword"
  "com.example.benchmark.TextInputTest#testTypeEmail"
  "com.example.benchmark.TextInputTest#testClearField"
  "com.example.benchmark.TextInputTest#testReplaceText"
  "com.example.benchmark.TextInputTest#testVerifyHint"
  "com.example.benchmark.TextInputTest#testMaxLengthEnforced"
  "com.example.benchmark.TextInputTest#testSpecialCharacters"
  "com.example.benchmark.TextInputTest#testMultilineInput"
  "com.example.benchmark.TextInputTest#testInputValidationError"
)

LIST_SCROLLING_TESTS=(
  "com.example.benchmark.ListScrollTest#testScrollToPosition20"
  "com.example.benchmark.ListScrollTest#testScrollToPosition40"
  "com.example.benchmark.ListScrollTest#testScrollToItemByText"
  "com.example.benchmark.ListScrollTest#testFlingDown"
  "com.example.benchmark.ListScrollTest#testFlingUp"
  "com.example.benchmark.ListScrollTest#testScrollAndClick"
  "com.example.benchmark.ListScrollTest#testScrollAndVerifyText"
  "com.example.benchmark.ListScrollTest#testHorizontalScroll"
  "com.example.benchmark.ListScrollTest#testNestedScroll"
  "com.example.benchmark.ListScrollTest#testScrollToEnd"
)

NAVIGATION_TESTS=(
  "com.example.benchmark.NavigationTest#testNavigateToSettings"
  "com.example.benchmark.NavigationTest#testNavigateToProfile"
  "com.example.benchmark.NavigationTest#testNavigateToSearch"
  "com.example.benchmark.NavigationTest#testDeepLinkHandling"
  "com.example.benchmark.NavigationTest#testBackNavigation"
  "com.example.benchmark.NavigationTest#testUpNavigation"
  "com.example.benchmark.NavigationTest#testTabSwitch"
  "com.example.benchmark.NavigationTest#testDrawerNavigation"
  "com.example.benchmark.NavigationTest#testBottomNavClick"
  "com.example.benchmark.NavigationTest#testIntentVerification"
)

ALL_TESTS=(
  "${VIEW_ASSERTION_TESTS[@]}"
  "${CLICK_INTERACTION_TESTS[@]}"
  "${TEXT_INPUT_TESTS[@]}"
  "${LIST_SCROLLING_TESTS[@]}"
  "${NAVIGATION_TESTS[@]}"
)

# ---------------------------------------------------------------------------
# Run a single Espresso test and capture timing
# ---------------------------------------------------------------------------
run_single_test() {
  local test_name="$1"
  local class_method="${test_name}"
  local start_time end_time elapsed

  start_time="$(date +%s)"

  local exit_code=0
  ${GRADLE_CMD} -p "${PROJECT_DIR}" \
    ":${MODULE}:connectedAndroidTest" \
    -Pandroid.testInstrumentationRunnerArguments.class="${class_method}" \
    --no-daemon \
    --quiet \
    2>/dev/null || exit_code=$?

  end_time="$(date +%s)"
  elapsed=$(( end_time - start_time ))

  echo "${exit_code}|${elapsed}"
}

# ---------------------------------------------------------------------------
# Main execution loop
# ---------------------------------------------------------------------------
echo "Espresso Benchmark Suite — 50 tests"
echo "Project: ${PROJECT_DIR}"
echo "Module:  ${MODULE}"
echo "Device:  $(adb devices | grep 'device$' | head -1 | awk '{print $1}')"
echo "---"
echo ""

total=0
passed=0
failed=0
flaky=0

for test in "${ALL_TESTS[@]}"; do
  short_name="${test##*#}"
  (( total++ )) || true

  result="$(run_single_test "${test}")"
  exit_code="${result%%|*}"
  elapsed="${result##*|}"

  if [[ "${exit_code}" -eq 0 ]]; then
    (( passed++ )) || true
    echo "[PASS] ${short_name} (${elapsed}s)"
  else
    # Retry once for flaky detection
    retry_result="$(run_single_test "${test}")"
    retry_code="${retry_result%%|*}"
    retry_elapsed="${retry_result##*|}"

    if [[ "${retry_code}" -eq 0 ]]; then
      (( flaky++ )) || true
      echo "[FLAKY] ${short_name} (${elapsed}s fail, ${retry_elapsed}s pass on retry)"
    else
      (( failed++ )) || true
      echo "[FAIL] ${short_name} (${elapsed}s)"
    fi
  fi
done

echo ""
echo "--- Espresso Suite Summary ---"
echo "Total:  ${total}"
echo "Passed: ${passed}"
echo "Failed: ${failed}"
echo "Flaky:  ${flaky}"
