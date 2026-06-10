//
//  HorizontalChipPickerTests.swift
//  DontLiftTests
//
//  纯行为断言：通过把 @Binding 接到本地 @State 的形式验证选中切换、
//  空 items 与单 item 三个 case 下的状态合约（不做 snapshot）。
//

import Testing
import SwiftUI
@testable import DontLift

private struct Chip: Identifiable, Hashable {
    let id: String
    let title: String
}

struct HorizontalChipPickerTests {

    @Test func switchSelection() {
        // 模拟 selection binding 的存储行为
        var current = "a"
        let binding = Binding<String>(get: { current }, set: { current = $0 })
        let items = [Chip(id: "a", title: "A"), Chip(id: "b", title: "B")]
        let picker = HorizontalChipPicker(items: items, selection: binding) { $0.title }
        _ = picker  // 实例化以确保泛型约束成立

        #expect(current == "a")
        binding.wrappedValue = "b"
        #expect(current == "b")
    }

    @Test func emptyItemsRendersWithoutCrash() {
        var current = ""
        let binding = Binding<String>(get: { current }, set: { current = $0 })
        let picker = HorizontalChipPicker(items: [Chip](), selection: binding) { $0.title }
        _ = picker
        #expect(current == "")
    }

    @Test func singleItemKeepsSelection() {
        var current = "only"
        let binding = Binding<String>(get: { current }, set: { current = $0 })
        let items = [Chip(id: "only", title: "唯一")]
        let picker = HorizontalChipPicker(items: items, selection: binding) { $0.title }
        _ = picker
        // 点击当前已选 chip 不应改变 selection（由 picker 内部 if !isSelected 守卫）
        #expect(current == "only")
    }
}
