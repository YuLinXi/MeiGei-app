import Foundation
import SwiftData
import Testing
@testable import DontLift

@MainActor
struct LocalModelSaveTests {
    @Test func insertEditAndDeletePublishOneCommittedEventEach() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let (events, observer) = observe(context)
        defer { NotificationCenter.default.removeObserver(observer) }
        let plan = WorkoutPlan(name: "保存事件")
        context.insert(plan)
        try LocalModelSave.save(context)
        #expect(events.values.count == 1)
        let inserted = try #require(events.values.first)
        #expect(identifiers(inserted, .insertedIdentifiers).contains(plan.persistentModelID))
        #expect((context.model(for: plan.persistentModelID) as? WorkoutPlan)?.name == "保存事件")

        plan.name = "已更新"
        try LocalModelSave.save(context)
        #expect(events.values.count == 2)
        #expect(identifiers(events.values[1], .updatedIdentifiers).contains(plan.persistentModelID))
        #expect(try ModelContext(container).fetch(FetchDescriptor<WorkoutPlan>()).first?.name == "已更新")

        let identity = plan.persistentModelID
        context.delete(plan)
        try LocalModelSave.save(context)
        #expect(events.values.count == 3)
        #expect(identifiers(events.values[2], .deletedIdentifiers).contains(identity))
        #expect(try ModelContext(container).fetch(FetchDescriptor<WorkoutPlan>()).isEmpty)
    }

    @Test func realReadonlyFailureDoesNotPublishSuccess() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "LocalSaveNotification-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try autoreleasepool {
            let url = directory.appending(path: "readonly.store")
            let writable = try ModelContainer(for: AppModelContainer.schema, configurations: [
                ModelConfiguration(schema: AppModelContainer.schema, url: url, cloudKitDatabase: .none)
            ])
            let writer = ModelContext(writable)
            writer.autosaveEnabled = false
            writer.insert(WorkoutPlan(name: "原计划"))
            try writer.save()
            let readonly = try ModelContainer(for: AppModelContainer.schema, configurations: [
                ModelConfiguration(schema: AppModelContainer.schema, url: url,
                                   allowsSave: false, cloudKitDatabase: .none)
            ])
            let context = ModelContext(readonly)
            context.autosaveEnabled = false
            let plan = try #require(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
            let (events, observer) = observe(context)
            defer { NotificationCenter.default.removeObserver(observer) }
            plan.name = "未保存的输入"
            #expect(throws: (any Error).self) { try LocalModelSave.save(context) }
            #expect(events.values.isEmpty)
            #expect(plan.name == "未保存的输入")
            #expect(try ModelContext(writable).fetch(FetchDescriptor<WorkoutPlan>()).first?.name == "原计划")
        }
    }

    private func identifiers(_ notification: Notification, _ key: ModelContext.NotificationKey) -> [PersistentIdentifier] {
        (notification.userInfo?[key.rawValue] as? [PersistentIdentifier]) ?? []
    }

    private func observe(_ context: ModelContext) -> (Events, NSObjectProtocol) {
        let events = Events()
        let identity = ObjectIdentifier(context)
        let observer = NotificationCenter.default.addObserver(forName: LocalModelSave.didSave, object: nil, queue: .main) { notification in
            guard let source = notification.object as? ModelContext, ObjectIdentifier(source) == identity else { return }
            MainActor.assumeIsolated { events.values.append(notification) }
        }
        return (events, observer)
    }

    @MainActor private final class Events {
        var values: [Notification] = []
    }
}
