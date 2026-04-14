# Appium vs Espresso: 50-Test Benchmark Results for 2026

Companion code for the Autonoma blog post 'Appium vs Espresso: 50-Test Benchmark Results for 2026'. Contains a 50-test Android benchmark harness with paired Appium (UIAutomator2) and Espresso spec files.

> Companion code for the Autonoma blog post: **[Appium vs Espresso: 50-Test Benchmark Results for 2026](https://getautonoma.com/blog/appium-vs-espresso-android-testing)**

## Requirements

Android SDK, Android emulator (API 34+), Java 17+, Gradle 8+. For Appium: Node.js 18+, Appium 2.x, UIAutomator2 driver.

## Quickstart

```bash
git clone https://github.com/Autonoma-Tools/appium-vs-espresso-android-testing.git
cd appium-vs-espresso-android-testing
# 1. Start an Android emulator (Pixel 7, API 34 recommended)
# 2. For Espresso:
bash benchmark/run.sh espresso
# 3. For Appium: Start Appium server first, then:
bash benchmark/run.sh appium
# 4. Results print execution time, flaky count, and CI cost estimate
```

## Project structure

```
benchmark/
  run.sh
  appium/
    run_suite.sh
  espresso/
    run_suite.sh
  results/          (generated at runtime)
examples/
  run-benchmark.sh
README.md
LICENSE
.gitignore
```

- `benchmark/` — primary source files for the benchmark harness referenced in the blog post.
- `examples/` — runnable examples you can execute as-is.

## About

This repository is maintained by [Autonoma](https://getautonoma.com) as reference material for the linked blog post. Autonoma builds autonomous AI agents that plan, execute, and maintain end-to-end tests directly from your codebase.

If something here is wrong, out of date, or unclear, please [open an issue](https://github.com/Autonoma-Tools/appium-vs-espresso-android-testing/issues/new).

## License

Released under the [MIT License](./LICENSE) © 2026 Autonoma Labs.
