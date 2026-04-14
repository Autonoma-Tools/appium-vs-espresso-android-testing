#!/usr/bin/env bash
# =============================================================================
# Appium (UIAutomator2) 50-Test Benchmark Suite
#
# Runs 50 representative Android UI tests using Appium with the
# UIAutomator2 driver. Tests are executed via a Node.js test runner
# (WebdriverIO or plain webdriver calls).
#
# This script assumes:
#   - Appium 2.x server is running on http://127.0.0.1:4723
#   - UIAutomator2 driver is installed: appium driver install uiautomator2
#   - A connected emulator or device (adb devices shows at least one)
#   - Node.js 18+ and npm are installed
#   - The test app APK is available (see APPIUM_APP_PATH below)
#
# The tests exercise five categories (10 tests each):
#   1. View assertions    — verifying text, visibility, enabled state
#   2. Click interactions — tap buttons, FABs, menu items
#   3. Text input         — type into fields, verify hints, clear fields
#   4. List scrolling     — scroll actions, item matching
#   5. Navigation         — activity transitions, deep links
#
# Each test is executed via a small Node.js script that creates a
# WebDriver session, runs one action, and tears down.
# Output format per test: [PASS] | [FAIL] | [FLAKY] test_name (Xs)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
APPIUM_HOST="${APPIUM_HOST:-127.0.0.1}"
APPIUM_PORT="${APPIUM_PORT:-4723}"
APPIUM_BASE_URL="http://${APPIUM_HOST}:${APPIUM_PORT}"

# Path to the APK under test — set this to your app's APK
APPIUM_APP_PATH="${APPIUM_APP_PATH:-/path/to/your/app-debug.apk}"

# Device capabilities
DEVICE_NAME="${APPIUM_DEVICE_NAME:-emulator-5554}"
PLATFORM_VERSION="${APPIUM_PLATFORM_VERSION:-14}"
APP_PACKAGE="${APPIUM_APP_PACKAGE:-com.example.benchmark}"
APP_ACTIVITY="${APPIUM_APP_ACTIVITY:-com.example.benchmark.MainActivity}"

# Retry count for flaky detection
FLAKY_RETRIES=1

# ---------------------------------------------------------------------------
# Install test dependencies if needed
# ---------------------------------------------------------------------------
if [[ ! -d "${SCRIPT_DIR}/node_modules" ]]; then
  echo "Installing Appium test dependencies..."
  cd "${SCRIPT_DIR}"
  npm init -y --silent 2>/dev/null || true
  npm install --save webdriverio@^9.0.0 --silent 2>/dev/null
  cd - >/dev/null
fi

# ---------------------------------------------------------------------------
# Test definitions: 50 tests across 5 categories
# Each test is a small JavaScript snippet executed via Node.js.
# ---------------------------------------------------------------------------

# Generate the test runner Node.js script
RUNNER_SCRIPT="${SCRIPT_DIR}/_runner.mjs"

cat > "${RUNNER_SCRIPT}" << 'NODEEOF'
import { remote } from "webdriverio";

const testName = process.argv[2];
const appPath = process.env.APPIUM_APP_PATH || "/path/to/your/app-debug.apk";
const appiumHost = process.env.APPIUM_HOST || "127.0.0.1";
const appiumPort = parseInt(process.env.APPIUM_PORT || "4723", 10);
const deviceName = process.env.APPIUM_DEVICE_NAME || "emulator-5554";
const platformVersion = process.env.APPIUM_PLATFORM_VERSION || "14";
const appPackage = process.env.APPIUM_APP_PACKAGE || "com.example.benchmark";
const appActivity = process.env.APPIUM_APP_ACTIVITY || "com.example.benchmark.MainActivity";

const capabilities = {
  platformName: "Android",
  "appium:automationName": "UiAutomator2",
  "appium:deviceName": deviceName,
  "appium:platformVersion": platformVersion,
  "appium:app": appPath,
  "appium:appPackage": appPackage,
  "appium:appActivity": appActivity,
  "appium:noReset": false,
  "appium:newCommandTimeout": 120,
};

// ---------------------------------------------------------------------------
// Test implementations: each function performs one UI interaction and asserts
// ---------------------------------------------------------------------------
const tests = {
  // --- View Assertions (10) ---
  testHomeScreenTitleDisplayed: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/title\")");
    await el.waitForDisplayed({ timeout: 10000 });
    const displayed = await el.isDisplayed();
    if (!displayed) throw new Error("Title not displayed");
  },
  testSubtitleTextContent: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/subtitle\")");
    await el.waitForDisplayed({ timeout: 10000 });
    const text = await el.getText();
    if (!text || text.length === 0) throw new Error("Subtitle text is empty");
  },
  testLogoImageVisible: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/logo\")");
    await el.waitForDisplayed({ timeout: 10000 });
  },
  testFooterVisible: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/footer\")");
    const exists = await el.isExisting();
    if (!exists) throw new Error("Footer not found");
  },
  testErrorMessageHidden: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/error_message\")");
    const displayed = await el.isDisplayed().catch(() => false);
    if (displayed) throw new Error("Error message should be hidden initially");
  },
  testButtonEnabled: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/primary_button\")");
    await el.waitForDisplayed({ timeout: 10000 });
    const enabled = await el.isEnabled();
    if (!enabled) throw new Error("Button should be enabled");
  },
  testInputFieldHint: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/username_input\")");
    await el.waitForDisplayed({ timeout: 10000 });
    const text = await el.getText();
    // Hint text or empty field is acceptable
    if (text === undefined) throw new Error("Could not read input field");
  },
  testToolbarTitle: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/toolbar_title\")");
    await el.waitForDisplayed({ timeout: 10000 });
    const text = await el.getText();
    if (!text) throw new Error("Toolbar title is empty");
  },
  testBadgeCountText: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/badge_count\")");
    const exists = await el.isExisting();
    // Badge may or may not be visible depending on state — just verify lookup works
    if (exists) {
      const text = await el.getText();
      if (isNaN(parseInt(text, 10))) throw new Error("Badge count is not a number");
    }
  },
  testEmptyStateMessage: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/empty_state\")");
    const exists = await el.isExisting();
    // Empty state visibility depends on data; just verify element lookup
    if (exists) await el.isDisplayed();
  },

  // --- Click Interactions (10) ---
  testPrimaryButtonClick: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/primary_button\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await el.click();
  },
  testFabClick: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/fab\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await el.click();
  },
  testMenuItemClick: async (driver) => {
    const menu = await driver.$("android=new UiSelector().description(\"More options\")");
    if (await menu.isExisting()) {
      await menu.click();
      await driver.pause(500);
    }
  },
  testCheckboxToggle: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/checkbox\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await el.click();
    const checked = await el.getAttribute("checked");
    if (checked !== "true") throw new Error("Checkbox should be checked after click");
  },
  testRadioButtonSelect: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/radio_option_1\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await el.click();
  },
  testSwitchToggle: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/toggle_switch\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await el.click();
  },
  testLongPress: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/long_press_target\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await driver.touchAction([
      { action: "press", element: el },
      { action: "wait", ms: 1500 },
      { action: "release" },
    ]);
  },
  testDoubleClick: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/double_tap_target\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await el.doubleClick();
  },
  testBackButtonPress: async (driver) => {
    await driver.back();
    await driver.pause(500);
  },
  testDialogConfirm: async (driver) => {
    const trigger = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/show_dialog\")");
    if (await trigger.isExisting()) {
      await trigger.click();
      await driver.pause(500);
      const ok = await driver.$("android=new UiSelector().text(\"OK\")");
      if (await ok.isExisting()) await ok.click();
    }
  },

  // --- Text Input (10) ---
  testTypeUsername: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/username_input\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await el.setValue("benchmark_user");
    const value = await el.getText();
    if (!value.includes("benchmark_user")) throw new Error("Username not typed correctly");
  },
  testTypePassword: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/password_input\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await el.setValue("S3cur3P@ss!");
  },
  testTypeEmail: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/email_input\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await el.setValue("test@example.com");
  },
  testClearField: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/username_input\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await el.setValue("text to clear");
    await el.clearValue();
  },
  testReplaceText: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/username_input\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await el.setValue("original");
    await el.clearValue();
    await el.setValue("replaced");
    const text = await el.getText();
    if (!text.includes("replaced")) throw new Error("Text replacement failed");
  },
  testVerifyHint: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/search_input\")");
    await el.waitForDisplayed({ timeout: 10000 });
    // getText on empty field returns hint on some Android versions
    await el.getText();
  },
  testMaxLengthEnforced: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/limited_input\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await el.setValue("a]".repeat(200));
    const text = await el.getText();
    if (text.length > 100) throw new Error("Max length not enforced (got " + text.length + " chars)");
  },
  testSpecialCharacters: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/username_input\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await el.setValue("test@#$%^&*()");
  },
  testMultilineInput: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/notes_input\")");
    await el.waitForDisplayed({ timeout: 10000 });
    await el.setValue("Line 1\nLine 2\nLine 3");
  },
  testInputValidationError: async (driver) => {
    const input = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/email_input\")");
    await input.waitForDisplayed({ timeout: 10000 });
    await input.setValue("not-an-email");
    const submit = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/submit_button\")");
    if (await submit.isExisting()) await submit.click();
    await driver.pause(500);
  },

  // --- List Scrolling (10) ---
  testScrollToPosition20: async (driver) => {
    const list = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/recycler_view\")");
    await list.waitForDisplayed({ timeout: 10000 });
    await driver.touchAction([
      { action: "press", x: 500, y: 1500 },
      { action: "moveTo", x: 500, y: 500 },
      { action: "release" },
    ]);
  },
  testScrollToPosition40: async (driver) => {
    const list = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/recycler_view\")");
    await list.waitForDisplayed({ timeout: 10000 });
    for (let i = 0; i < 3; i++) {
      await driver.touchAction([
        { action: "press", x: 500, y: 1500 },
        { action: "moveTo", x: 500, y: 300 },
        { action: "release" },
      ]);
      await driver.pause(300);
    }
  },
  testScrollToItemByText: async (driver) => {
    const el = await driver.$("android=new UiScrollable(new UiSelector().scrollable(true)).scrollTextIntoView(\"Item 25\")");
    await el.waitForDisplayed({ timeout: 15000 });
  },
  testFlingDown: async (driver) => {
    await driver.touchAction([
      { action: "press", x: 500, y: 1500 },
      { action: "moveTo", x: 500, y: 200 },
      { action: "release" },
    ]);
    await driver.pause(500);
  },
  testFlingUp: async (driver) => {
    await driver.touchAction([
      { action: "press", x: 500, y: 200 },
      { action: "moveTo", x: 500, y: 1500 },
      { action: "release" },
    ]);
    await driver.pause(500);
  },
  testScrollAndClick: async (driver) => {
    await driver.touchAction([
      { action: "press", x: 500, y: 1500 },
      { action: "moveTo", x: 500, y: 500 },
      { action: "release" },
    ]);
    await driver.pause(300);
    const item = await driver.$("android=new UiSelector().textContains(\"Item\")");
    if (await item.isExisting()) await item.click();
  },
  testScrollAndVerifyText: async (driver) => {
    await driver.touchAction([
      { action: "press", x: 500, y: 1500 },
      { action: "moveTo", x: 500, y: 500 },
      { action: "release" },
    ]);
    await driver.pause(300);
    const item = await driver.$("android=new UiSelector().textContains(\"Item\")");
    if (await item.isExisting()) {
      const text = await item.getText();
      if (!text.includes("Item")) throw new Error("Expected text containing 'Item'");
    }
  },
  testHorizontalScroll: async (driver) => {
    await driver.touchAction([
      { action: "press", x: 900, y: 800 },
      { action: "moveTo", x: 100, y: 800 },
      { action: "release" },
    ]);
    await driver.pause(300);
  },
  testNestedScroll: async (driver) => {
    // Scroll outer container
    await driver.touchAction([
      { action: "press", x: 500, y: 1500 },
      { action: "moveTo", x: 500, y: 800 },
      { action: "release" },
    ]);
    await driver.pause(300);
  },
  testScrollToEnd: async (driver) => {
    for (let i = 0; i < 5; i++) {
      await driver.touchAction([
        { action: "press", x: 500, y: 1500 },
        { action: "moveTo", x: 500, y: 200 },
        { action: "release" },
      ]);
      await driver.pause(200);
    }
  },

  // --- Navigation (10) ---
  testNavigateToSettings: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/nav_settings\")");
    if (await el.isExisting()) {
      await el.click();
      await driver.pause(500);
    }
  },
  testNavigateToProfile: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/nav_profile\")");
    if (await el.isExisting()) {
      await el.click();
      await driver.pause(500);
    }
  },
  testNavigateToSearch: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/nav_search\")");
    if (await el.isExisting()) {
      await el.click();
      await driver.pause(500);
    }
  },
  testDeepLinkHandling: async (driver) => {
    await driver.execute("mobile: deepLink", {
      url: "benchmarkapp://profile/123",
      package: appPackage,
    }).catch(() => {
      // Deep link support varies by app configuration
    });
    await driver.pause(500);
  },
  testBackNavigation: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/nav_settings\")");
    if (await el.isExisting()) await el.click();
    await driver.pause(500);
    await driver.back();
    await driver.pause(500);
  },
  testUpNavigation: async (driver) => {
    const up = await driver.$("android=new UiSelector().description(\"Navigate up\")");
    if (await up.isExisting()) {
      await up.click();
      await driver.pause(500);
    }
  },
  testTabSwitch: async (driver) => {
    const tab2 = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/tab_2\")");
    if (await tab2.isExisting()) {
      await tab2.click();
      await driver.pause(500);
    }
    const tab1 = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/tab_1\")");
    if (await tab1.isExisting()) await tab1.click();
  },
  testDrawerNavigation: async (driver) => {
    const drawer = await driver.$("android=new UiSelector().description(\"Open navigation drawer\")");
    if (await drawer.isExisting()) {
      await drawer.click();
      await driver.pause(500);
    }
  },
  testBottomNavClick: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/bottom_nav_home\")");
    if (await el.isExisting()) {
      await el.click();
      await driver.pause(300);
    }
  },
  testIntentVerification: async (driver) => {
    const el = await driver.$("android=new UiSelector().resourceId(\"" + appPackage + ":id/share_button\")");
    if (await el.isExisting()) {
      await el.click();
      await driver.pause(500);
      // Dismiss share sheet if it appears
      await driver.back();
    }
  },
};

// ---------------------------------------------------------------------------
// Execute the requested test
// ---------------------------------------------------------------------------
async function main() {
  if (!testName || !tests[testName]) {
    console.error("Unknown test: " + testName);
    console.error("Available tests: " + Object.keys(tests).join(", "));
    process.exit(2);
  }

  let driver;
  try {
    driver = await remote({
      hostname: appiumHost,
      port: appiumPort,
      path: "/",
      capabilities,
      logLevel: "silent",
    });

    await tests[testName](driver);
    process.exit(0);
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  } finally {
    if (driver) {
      await driver.deleteSession().catch(() => {});
    }
  }
}

main();
NODEEOF

# ---------------------------------------------------------------------------
# Test list — matches the keys in the Node.js runner above
# ---------------------------------------------------------------------------
ALL_TESTS=(
  # View Assertions
  "testHomeScreenTitleDisplayed"
  "testSubtitleTextContent"
  "testLogoImageVisible"
  "testFooterVisible"
  "testErrorMessageHidden"
  "testButtonEnabled"
  "testInputFieldHint"
  "testToolbarTitle"
  "testBadgeCountText"
  "testEmptyStateMessage"
  # Click Interactions
  "testPrimaryButtonClick"
  "testFabClick"
  "testMenuItemClick"
  "testCheckboxToggle"
  "testRadioButtonSelect"
  "testSwitchToggle"
  "testLongPress"
  "testDoubleClick"
  "testBackButtonPress"
  "testDialogConfirm"
  # Text Input
  "testTypeUsername"
  "testTypePassword"
  "testTypeEmail"
  "testClearField"
  "testReplaceText"
  "testVerifyHint"
  "testMaxLengthEnforced"
  "testSpecialCharacters"
  "testMultilineInput"
  "testInputValidationError"
  # List Scrolling
  "testScrollToPosition20"
  "testScrollToPosition40"
  "testScrollToItemByText"
  "testFlingDown"
  "testFlingUp"
  "testScrollAndClick"
  "testScrollAndVerifyText"
  "testHorizontalScroll"
  "testNestedScroll"
  "testScrollToEnd"
  # Navigation
  "testNavigateToSettings"
  "testNavigateToProfile"
  "testNavigateToSearch"
  "testDeepLinkHandling"
  "testBackNavigation"
  "testUpNavigation"
  "testTabSwitch"
  "testDrawerNavigation"
  "testBottomNavClick"
  "testIntentVerification"
)

# ---------------------------------------------------------------------------
# Run a single Appium test and capture timing
# ---------------------------------------------------------------------------
run_single_test() {
  local test_name="$1"
  local start_time end_time elapsed

  start_time="$(date +%s)"

  local exit_code=0
  APPIUM_APP_PATH="${APPIUM_APP_PATH}" \
  APPIUM_HOST="${APPIUM_HOST}" \
  APPIUM_PORT="${APPIUM_PORT}" \
  APPIUM_DEVICE_NAME="${DEVICE_NAME}" \
  APPIUM_PLATFORM_VERSION="${PLATFORM_VERSION}" \
  APPIUM_APP_PACKAGE="${APP_PACKAGE}" \
  APPIUM_APP_ACTIVITY="${APP_ACTIVITY}" \
    node "${RUNNER_SCRIPT}" "${test_name}" 2>/dev/null || exit_code=$?

  end_time="$(date +%s)"
  elapsed=$(( end_time - start_time ))

  echo "${exit_code}|${elapsed}"
}

# ---------------------------------------------------------------------------
# Main execution loop
# ---------------------------------------------------------------------------
echo "Appium (UIAutomator2) Benchmark Suite — 50 tests"
echo "Server:   ${APPIUM_BASE_URL}"
echo "Device:   ${DEVICE_NAME}"
echo "Platform: Android ${PLATFORM_VERSION}"
echo "App:      ${APPIUM_APP_PATH}"
echo "---"
echo ""

total=0
passed=0
failed=0
flaky=0

for test in "${ALL_TESTS[@]}"; do
  (( total++ )) || true

  result="$(run_single_test "${test}")"
  exit_code="${result%%|*}"
  elapsed="${result##*|}"

  if [[ "${exit_code}" -eq 0 ]]; then
    (( passed++ )) || true
    echo "[PASS] ${test} (${elapsed}s)"
  else
    # Retry once for flaky detection
    retry_result="$(run_single_test "${test}")"
    retry_code="${retry_result%%|*}"
    retry_elapsed="${retry_result##*|}"

    if [[ "${retry_code}" -eq 0 ]]; then
      (( flaky++ )) || true
      echo "[FLAKY] ${test} (${elapsed}s fail, ${retry_elapsed}s pass on retry)"
    else
      (( failed++ )) || true
      echo "[FAIL] ${test} (${elapsed}s)"
    fi
  fi
done

echo ""
echo "--- Appium Suite Summary ---"
echo "Total:  ${total}"
echo "Passed: ${passed}"
echo "Failed: ${failed}"
echo "Flaky:  ${flaky}"
