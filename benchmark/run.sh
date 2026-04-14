#!/usr/bin/env bash
# =============================================================================
# Appium vs Espresso: 50-Test Android Benchmark Runner
#
# Companion code for:
#   https://getautonoma.com/blog/appium-vs-espresso-android-testing
#
# Usage:
#   bash benchmark/run.sh espresso
#   bash benchmark/run.sh appium
#   bash benchmark/run.sh all        # runs both sequentially
#
# Prerequisites:
#   - Android emulator running (Pixel 7, API 34 recommended)
#   - For Espresso: Android SDK, Gradle 8+, Java 17+
#   - For Appium:   Node.js 18+, Appium 2.x server running, UIAutomator2 driver
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# ---------------------------------------------------------------------------
# Constants for CI cost estimation
# ---------------------------------------------------------------------------
RUNS_PER_WEEK=50           # typical CI pipeline: ~50 test runs/week
CI_COST_PER_MINUTE=0.08    # average cloud CI cost per minute (USD)

# ---------------------------------------------------------------------------
# Color output helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}=============================================${NC}"
  echo -e "${BOLD}${CYAN}  $1${NC}"
  echo -e "${BOLD}${CYAN}=============================================${NC}"
  echo ""
}

print_metric() {
  local label="$1"
  local value="$2"
  printf "  ${BOLD}%-30s${NC} %s\n" "${label}:" "${value}"
}

print_success() {
  echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
}

print_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  echo "Usage: bash benchmark/run.sh <framework>"
  echo ""
  echo "Frameworks:"
  echo "  espresso   Run the 50-test Espresso benchmark suite"
  echo "  appium     Run the 50-test Appium benchmark suite"
  echo "  all        Run both suites sequentially and compare"
  echo ""
  echo "Options:"
  echo "  --help     Show this help message"
  exit 1
}

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
check_emulator() {
  if ! command -v adb &>/dev/null; then
    echo -e "${RED}Error: adb not found. Install Android SDK platform-tools.${NC}"
    exit 1
  fi

  local devices
  devices="$(adb devices 2>/dev/null | grep -c 'device$' || true)"
  if [[ "${devices}" -lt 1 ]]; then
    echo -e "${RED}Error: No Android emulator or device detected.${NC}"
    echo "Start an emulator first:  emulator -avd Pixel_7_API_34"
    exit 1
  fi
  echo -e "${GREEN}Emulator/device detected (${devices} device(s) connected).${NC}"
}

check_espresso_deps() {
  if ! command -v java &>/dev/null; then
    echo -e "${RED}Error: java not found. Install Java 17+.${NC}"
    exit 1
  fi
  local java_version
  java_version="$(java -version 2>&1 | head -1)"
  echo "  Java: ${java_version}"

  if ! command -v gradle &>/dev/null && [[ ! -f "./gradlew" ]]; then
    print_warn "Neither gradle nor ./gradlew found. Espresso suite requires a Gradle project."
  fi
}

check_appium_deps() {
  if ! command -v node &>/dev/null; then
    echo -e "${RED}Error: node not found. Install Node.js 18+.${NC}"
    exit 1
  fi
  echo "  Node: $(node --version)"

  if ! command -v appium &>/dev/null; then
    echo -e "${RED}Error: appium CLI not found. Install with: npm install -g appium${NC}"
    exit 1
  fi
  echo "  Appium: $(appium --version 2>/dev/null || echo 'unknown')"

  # Check if Appium server is reachable
  if command -v curl &>/dev/null; then
    local status_code
    status_code="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:4723/status 2>/dev/null || echo '000')"
    if [[ "${status_code}" == "200" ]]; then
      echo -e "  ${GREEN}Appium server is running on port 4723.${NC}"
    else
      print_warn "Appium server not reachable at http://127.0.0.1:4723/status"
      echo "  Start it with:  appium --relaxed-security"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Run a single framework benchmark
# ---------------------------------------------------------------------------
run_framework() {
  local framework="$1"
  local suite_script="${SCRIPT_DIR}/${framework}/run_suite.sh"

  if [[ ! -f "${suite_script}" ]]; then
    echo -e "${RED}Error: Suite script not found: ${suite_script}${NC}"
    exit 1
  fi

  print_header "Running ${framework^^} benchmark (50 tests)"

  echo "Preflight checks for ${framework}..."
  check_emulator
  if [[ "${framework}" == "espresso" ]]; then
    check_espresso_deps
  elif [[ "${framework}" == "appium" ]]; then
    check_appium_deps
  fi
  echo ""

  # Create results directory
  mkdir -p "${RESULTS_DIR}"

  local result_file="${RESULTS_DIR}/${framework}_${TIMESTAMP}.json"
  local start_time end_time elapsed_seconds

  start_time="$(date +%s)"

  # Execute the framework-specific suite
  # The suite script is expected to:
  #   - Run 50 tests against the connected emulator
  #   - Print per-test PASS/FAIL lines to stdout
  #   - Exit 0 if the suite completed (even with flaky failures)
  echo "Executing suite: ${suite_script}"
  echo "---"

  local suite_output
  local suite_exit_code=0
  suite_output="$(bash "${suite_script}" 2>&1)" || suite_exit_code=$?

  end_time="$(date +%s)"
  elapsed_seconds=$(( end_time - start_time ))

  echo "${suite_output}"
  echo "---"
  echo ""

  # Parse results from suite output
  local total_tests=0
  local passed_tests=0
  local failed_tests=0
  local flaky_tests=0

  while IFS= read -r line; do
    if [[ "${line}" == *"[PASS]"* ]]; then
      (( total_tests++ )) || true
      (( passed_tests++ )) || true
    elif [[ "${line}" == *"[FAIL]"* ]]; then
      (( total_tests++ )) || true
      (( failed_tests++ )) || true
    elif [[ "${line}" == *"[FLAKY]"* ]]; then
      (( total_tests++ )) || true
      (( flaky_tests++ )) || true
    fi
  done <<< "${suite_output}"

  # If no structured output was parsed, use defaults from the suite
  if [[ "${total_tests}" -eq 0 ]]; then
    total_tests=50
    print_warn "Could not parse per-test results. Using total=50."
  fi

  # Calculate metrics
  local elapsed_minutes
  elapsed_minutes="$(echo "scale=2; ${elapsed_seconds} / 60" | bc 2>/dev/null || echo "N/A")"

  local avg_per_test
  avg_per_test="$(echo "scale=2; ${elapsed_seconds} / ${total_tests}" | bc 2>/dev/null || echo "N/A")"

  local ci_minutes_per_week
  ci_minutes_per_week="$(echo "scale=1; (${elapsed_seconds} / 60) * ${RUNS_PER_WEEK}" | bc 2>/dev/null || echo "N/A")"

  local ci_cost_per_week
  ci_cost_per_week="$(echo "scale=2; ${ci_minutes_per_week} * ${CI_COST_PER_MINUTE}" | bc 2>/dev/null || echo "N/A")"

  # Print summary
  print_header "${framework^^} Benchmark Results"

  print_metric "Framework" "${framework}"
  print_metric "Total tests" "${total_tests}"
  print_metric "Passed" "${passed_tests}"
  print_metric "Failed" "${failed_tests}"
  print_metric "Flaky" "${flaky_tests}"
  print_metric "Total time" "${elapsed_seconds}s (${elapsed_minutes} min)"
  print_metric "Avg per test" "${avg_per_test}s"
  print_metric "Est. CI min/week" "${ci_minutes_per_week} min (${RUNS_PER_WEEK} runs)"
  print_metric "Est. CI cost/week" "\$${ci_cost_per_week}"
  echo ""

  if [[ "${suite_exit_code}" -ne 0 ]]; then
    print_warn "Suite exited with code ${suite_exit_code}."
  fi

  # Write JSON results file
  cat > "${result_file}" <<EOF
{
  "framework": "${framework}",
  "timestamp": "${TIMESTAMP}",
  "total_tests": ${total_tests},
  "passed": ${passed_tests},
  "failed": ${failed_tests},
  "flaky": ${flaky_tests},
  "elapsed_seconds": ${elapsed_seconds},
  "elapsed_minutes": "${elapsed_minutes}",
  "avg_seconds_per_test": "${avg_per_test}",
  "ci_minutes_per_week": "${ci_minutes_per_week}",
  "ci_cost_per_week_usd": "${ci_cost_per_week}",
  "ci_runs_per_week": ${RUNS_PER_WEEK},
  "ci_cost_per_minute_usd": ${CI_COST_PER_MINUTE}
}
EOF

  echo -e "Results saved to: ${CYAN}${result_file}${NC}"
}

# ---------------------------------------------------------------------------
# Compare two result files side by side
# ---------------------------------------------------------------------------
compare_results() {
  local espresso_file="$1"
  local appium_file="$2"

  print_header "Head-to-Head Comparison"

  printf "  ${BOLD}%-25s %15s %15s${NC}\n" "Metric" "Espresso" "Appium"
  echo "  ---------------------------------------------------------------"

  # Helper to extract a JSON field (simple grep-based, no jq dependency)
  extract() {
    local file="$1" key="$2"
    grep "\"${key}\"" "${file}" | head -1 | sed 's/.*: *"\?\([^",}]*\)"\?.*/\1/'
  }

  local metrics=("total_tests" "passed" "failed" "flaky" "elapsed_seconds" "avg_seconds_per_test" "ci_minutes_per_week" "ci_cost_per_week_usd")
  local labels=("Total tests" "Passed" "Failed" "Flaky" "Total time (s)" "Avg per test (s)" "CI min/week" "CI cost/week (USD)")

  for i in "${!metrics[@]}"; do
    local ev av
    ev="$(extract "${espresso_file}" "${metrics[$i]}")"
    av="$(extract "${appium_file}" "${metrics[$i]}")"
    printf "  %-25s %15s %15s\n" "${labels[$i]}" "${ev}" "${av}"
  done

  echo ""
  echo -e "  ${BOLD}Conclusion:${NC} Compare elapsed_seconds to see which framework"
  echo "  is faster for your specific device configuration."
  echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  if [[ $# -lt 1 ]] || [[ "$1" == "--help" ]]; then
    usage
  fi

  local framework="$1"

  case "${framework}" in
    espresso)
      run_framework "espresso"
      ;;
    appium)
      run_framework "appium"
      ;;
    all)
      run_framework "espresso"
      local espresso_result
      espresso_result="$(ls -t "${RESULTS_DIR}"/espresso_*.json 2>/dev/null | head -1)"

      run_framework "appium"
      local appium_result
      appium_result="$(ls -t "${RESULTS_DIR}"/appium_*.json 2>/dev/null | head -1)"

      if [[ -n "${espresso_result}" && -n "${appium_result}" ]]; then
        compare_results "${espresso_result}" "${appium_result}"
      fi
      ;;
    *)
      echo -e "${RED}Unknown framework: ${framework}${NC}"
      usage
      ;;
  esac
}

main "$@"
