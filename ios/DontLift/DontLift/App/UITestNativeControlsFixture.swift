#if DEBUG
import SwiftUI

/// 只在假登录的隔离库中展示真实公共控件，验证长文案与大字；不写业务数据。
struct UITestNativeControlsFixture: View {
    @State private var count = 0
    @State private var selection = "all"
    @State private var result = "尚未选择菜单"
    @State private var showsSheet = false

    private let chips = [LibraryChip(id: "all", title: "全部"),
                         LibraryChip(id: "chest", title: "胸"),
                         LibraryChip(id: "back", title: "背")]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                HStack(spacing: 16) {
                    CircleIconButton(systemName: "minus", accessibilityLabel: "减少示例值") { count -= 1 }
                    Text("\(count)").font(Theme.Font.l4).accessibilityIdentifier("fixture.count")
                    CircleIconButton(systemName: "plus", accessibilityLabel: "增加示例值") { count += 1 }
                }
                HorizontalChipPicker(items: chips, selection: $selection) { $0.title }
                PaperActionMenuButton(items: (1...8).map { index in
                    PaperMenuItem(title: "为这次实际训练另存第\(index)份个人计划", systemImage: "doc.badge.plus") {
                        result = "已选择第\(index)项"
                    }
                }, accessibilityLabel: "展开长操作菜单") { _ in
                    CircleIconLabel(systemName: "ellipsis")
                }
                Button("打开长标题表单") { showsSheet = true }
                    .font(Theme.Font.l4)
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                Text(result).font(Theme.Font.l4).accessibilityIdentifier("fixture.result")
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .foregroundStyle(Theme.Color.fg)
        .sheet(isPresented: $showsSheet) {
            VStack {
                PaperSheetHeader(title: "从本次训练保留逐组安排并另存为个人计划",
                                 confirmTitle: "确认保存个人计划",
                                 onCancel: { showsSheet = false }, onConfirm: {
                    result = "已确认长标题表单"
                    showsSheet = false
                })
                Spacer(minLength: 0)
            }
            .background(Theme.Color.bg.ignoresSafeArea())
        }
    }
}
#endif
