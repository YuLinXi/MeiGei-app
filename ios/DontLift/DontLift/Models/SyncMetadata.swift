import Foundation

/// 本地同步状态机（离线优先，见 design.md D2/D3）。
enum SyncStatus: String, Codable, CaseIterable {
    /// 本地新建，尚未成功上传。
    case pendingCreate
    /// 本地已有改动待上传。
    case pendingUpdate
    /// 本地标记删除（软删墓碑）待上传。
    case pendingDelete
    /// 与服务端一致。
    case synced
    /// 服务端版本较新（last-write-wins 落败），等待用户人工处理。
    case conflicted
}

/// 统一同步信封：所有参与云同步的本地实体都携带这组字段。
///
/// 主键策略（design.md Resolved）：客户端用 UUID v7 离线预生成 `localId`，
/// 与服务端 `serverId` 取同一值；`serverId` 为 nil 表示尚未被服务端确认接收，
/// 用以驱动同步引擎判断「是否已落库」。
protocol Syncable: AnyObject {
    var localId: UUID { get }
    var serverId: UUID? { get set }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
    var version: Int { get set }
    var syncStatusRaw: String { get set }
}

extension Syncable {
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingCreate }
        set { syncStatusRaw = newValue.rawValue }
    }

    /// 本地一次编辑：刷新 updatedAt 并标记待上传（已删除的不回退状态）。
    func markDirty(now: Date = .now) {
        updatedAt = now
        if syncStatus != .pendingDelete {
            syncStatus = (serverId == nil) ? .pendingCreate : .pendingUpdate
        }
    }

    /// 本地软删：打墓碑，等待把删除同步给服务端 / 其他设备。
    func markDeleted(now: Date = .now) {
        deletedAt = now
        updatedAt = now
        syncStatus = .pendingDelete
    }
}
