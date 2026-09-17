# 自动验证摘录（2026-09-18）

以下摘录来自本地 xcodebuild 输出；完整 xcresult 保留在本机 /tmp，不纳入 Git。

## regression

结果包：`/tmp/dontlift-perf-regression.xcresult`

```text
✔ Test run with 274 tests in 37 suites passed after 51.869 seconds.
Test Case '-[DontLiftUITests.WorkoutInteractionPerformanceTests testLongWorkoutInputAndRestOverlay]' passed (53.408 seconds).
** TEST SUCCEEDED **
```

## closeout

结果包：`/tmp/dontlift-perf-closeout.xcresult`

```text
✔ Test run with 23 tests in 3 suites passed after 0.874 seconds.
Test Case '-[DontLiftUITests.WorkoutInteractionPerformanceTests testLongWorkoutInputAndRestOverlay]' passed (55.201 seconds).
** TEST SUCCEEDED **
```

closeout 在最终改动后重跑 23 项徽章／历史测试及长列表 UI，并显式等待“完成休息”按钮以确认浮层已展开。全量 274 项测试在 regression 轮通过。

OpenSpec 严格校验与 git diff --check 通过。
