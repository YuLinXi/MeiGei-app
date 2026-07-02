import Foundation

// MARK: - 鉴权 / 设备

struct AppleLoginRequest: Encodable {
    let identityToken: String
    /// 可选：仅首次/重新授权时 Apple 才下发。后端据此换取并持久化 refresh_token 供删号 revoke。
    var authorizationCode: String?
}

struct AuthResponse: Decodable {
    let token: String
    let userId: UUID
    let newUser: Bool
}

// MARK: - 用户画像（服务端权威域，非 LWW 同步）

/// `GET /me` / `PATCH /account/profile` 响应。displayName 为空 = 称呼未补全（首登门控信号）。
struct ProfileDTO: Decodable {
    let userId: UUID
    let displayName: String?
    /// 可空：null 表示从未设置，客户端保留本地、展示按男。
    let sex: String?
    let email: String?
}

/// `PATCH /account/profile` 请求体。仅采集称呼 / 性别两字段，
/// 合成的 Encodable 对 nil 走 encodeIfPresent → 自动省略未改字段（PATCH 语义）。
struct ProfilePatchRequest: Encodable {
    var displayName: String?
    var sex: String?
}

/// 删号影响面（GET /account/deletion-impact）。
struct DeletionImpactDTO: Decodable {
    let ownedTeamsToTransfer: Int
    let emptyOwnedTeamsToDelete: Int
    let affectedMembers: Int
}

struct RegisterTokenRequest: Encodable {
    let apnsToken: String
    let environment: String
}

// MARK: - 通用同步信封

/// 上传请求体：`{ "items": [...] }`。
struct SyncPushRequest<T: Encodable>: Encodable {
    let items: [T]
}

/// 增量下拉结果：变更集 + 服务端时间（作下次 since 水位）。
struct SyncPullResult<T: Decodable>: Decodable {
    let changes: [T]
    let serverTime: Date
}

/// 服务端胜出的冲突项（LWW 落败，回传服务端当前值供人工提示）。
struct SyncConflict<T: Decodable>: Decodable {
    let id: UUID
    let serverValue: T
}

/// 服务端校正客户端偏移时间戳的通知。
struct SyncTimestampAdjustmentDTO: Decodable {
    let id: UUID
    let domain: String
    let originalUpdatedAt: Date?
    let adjustedAt: Date
    let reason: String?
}

/// 上传结果：已落库 id + 冲突 + 服务端时间 + 时间戳校正通知。
struct SyncPushResult<T: Decodable>: Decodable {
    let applied: [UUID]
    let conflicts: [SyncConflict<T>]
    let serverTime: Date
    let timestampAdjustments: [SyncTimestampAdjustmentDTO]

    private enum CodingKeys: String, CodingKey {
        case applied
        case conflicts
        case serverTime
        case timestampAdjustments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        applied = try container.decode([UUID].self, forKey: .applied)
        conflicts = try container.decode([SyncConflict<T>].self, forKey: .conflicts)
        serverTime = try container.decode(Date.self, forKey: .serverTime)
        timestampAdjustments = try container.decodeIfPresent(
            [SyncTimestampAdjustmentDTO].self,
            forKey: .timestampAdjustments
        ) ?? []
    }
}

// MARK: - 各域实体 DTO（字段对齐后端 Jackson camelCase）

struct CustomExerciseDTO: Codable {
    var id: UUID
    var userId: UUID?
    var name: String
    var primaryMuscle: String?
    var equipmentType: String?
    var createdAt: Date?
    var updatedAt: Date
    var deletedAt: Date?
    var version: Int?
}

struct WorkoutPlanGroupDTO: Codable {
    var id: UUID
    var userId: UUID?
    var name: String
    /// 解码缺失时客户端兜底 0，兼容早期开发数据。
    var sortOrder: Int?
    var createdAt: Date?
    var updatedAt: Date
    var deletedAt: Date?
    var version: Int?
}

struct WorkoutPlanDTO: Codable {
    var id: UUID
    var userId: UUID?
    var name: String
    /// 注意：后端 items 是 jsonb **字符串**，非数组。
    var items: String
    /// 计划模式 raw（"strict"/"adaptive"）。解码缺失时兜底 `adaptive`，兼容旧后端/旧数据。
    var mode: String?
    var forkedFrom: UUID?
    var forkedFromShareVersionId: UUID?
    var sharedToTeamId: UUID?
    var groupId: UUID?
    /// 解码缺失时客户端兜底 0，兼容旧后端/旧数据。
    var sortOrder: Int?
    var createdAt: Date?
    var updatedAt: Date
    var deletedAt: Date?
    var version: Int?
}

// MARK: - 训练聚合树（workout + 动作/组子树）

struct WorkoutDTO: Codable {
    var id: UUID
    var userId: UUID?
    var planId: UUID?
    var sourceShareId: UUID?
    var sourceShareVersionId: UUID?
    var sourcePlanNameSnapshot: String?
    var title: String?
    var startedAt: Date?
    var endedAt: Date?
    var note: String?
    var createdAt: Date?
    var updatedAt: Date
    var deletedAt: Date?
    var version: Int?
}

struct WorkoutExerciseDTO: Codable {
    var id: UUID
    var workoutId: UUID?
    var userId: UUID?
    var builtinExerciseCode: String?
    var customExerciseId: UUID?
    var exerciseName: String
    var primaryMuscle: String?
    var orderIndex: Int
    var note: String?
    /// 来源计划项 itemId（自适应回写合并主键）。解码缺失为 nil（临时新增/旧数据）。
    var planItemId: UUID?
}

struct WorkoutSetDTO: Codable {
    var id: UUID
    var workoutExerciseId: UUID?
    var setIndex: Int
    var weightKg: Double?
    var reps: Int?
    var completed: Bool?
    var note: String?
    /// 完成该组后启动休息时采用的预计秒数；旧后端/旧数据缺失时为 nil。
    var plannedRestSeconds: Int?
    /// 该组休息完成后的真实秒数；旧后端/旧数据缺失时为 nil。
    var actualRestSeconds: Int?
    /// 组类型 raw（"working"/"warmup"）。解码缺失时由 SyncEngine 兜底 `working`，兼容旧后端/旧数据。
    var setType: String?
    /// 递减组分段 JSON 字符串；旧后端/旧数据缺失时按空数组处理。
    var segments: String?
}

struct WorkoutTreeDTO: Codable {
    var workout: WorkoutDTO
    var exercises: [ExerciseNode]

    struct ExerciseNode: Codable {
        var exercise: WorkoutExerciseDTO
        var sets: [WorkoutSetDTO]
    }
}

// MARK: - Team 域（服务端权威，非离线同步）

struct TeamDTO: Decodable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var ownerUserId: UUID
    var inviteCode: String
    var createdAt: Date?
    var ownerTransferredAt: Date?
    var ownerTransferredFromUserId: UUID?
}

struct TeamMemberDTO: Decodable, Identifiable, Hashable {
    var id: UUID
    var teamId: UUID
    var userId: UUID
    var role: String        // owner | member
    var joinedAt: Date?
    /// 后端 join app_user.display_name 得到；用户未设名时为 nil，前端兜底。
    var displayName: String?
    /// 当前用户在某个 Team 的训练完成自动分享偏好。旧后端未返回时按 false 处理。
    var autoShareWorkouts: Bool

    enum CodingKeys: String, CodingKey {
        case id, teamId, userId, role, joinedAt, displayName, autoShareWorkouts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        teamId = try c.decode(UUID.self, forKey: .teamId)
        userId = try c.decode(UUID.self, forKey: .userId)
        role = try c.decode(String.self, forKey: .role)
        joinedAt = try c.decodeIfPresent(Date.self, forKey: .joinedAt)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        autoShareWorkouts = try c.decodeIfPresent(Bool.self, forKey: .autoShareWorkouts) ?? false
    }
}

/// 队友打卡。`summary` 为后端 jsonb，序列化为 JSON **字符串**（同 WorkoutPlanDTO.items），需二次解析。
struct TeamCheckinDTO: Decodable, Identifiable, Hashable {
    var id: UUID
    var teamId: UUID
    var userId: UUID
    var workoutId: UUID
    var checkinDate: String  // LocalDate -> "yyyy-MM-dd"
    var summary: String
    var createdAt: Date?

    var decodedSummary: CheckinSummary? {
        guard let data = summary.data(using: .utf8) else { return nil }
        return try? JSONCoding.decoder.decode(CheckinSummary.self, from: data)
    }

    /// 解析嵌套快照；坏数据时给空摘要兜底。
    var parsedSummary: CheckinSummary {
        guard let s = decodedSummary else {
            return CheckinSummary(title: nil, startedAt: nil, endedAt: nil,
                                  exerciseCount: 0, totalSets: 0, totalVolumeKg: 0, exercises: [])
        }
        return s
    }
}

struct CheckinReactionDTO: Decodable, Identifiable, Hashable {
    var id: UUID
    var checkinId: UUID
    var userId: UUID
    var emoji: String        // muscle | fire | clap | heart
}

struct TeamCheckinFeedDTO: Decodable {
    var checkins: [TeamCheckinDTO]
    var reactions: [CheckinReactionDTO]
}

/// 服务端计划模板（Team 内浏览/Fork 用，items 同为 jsonb 字符串）。
struct ServerPlanDTO: Decodable, Identifiable, Hashable {
    var id: UUID
    var userId: UUID?
    var name: String
    var items: String
    var forkedFrom: UUID?
    var forkedFromShareVersionId: UUID?
    var sharedToTeamId: UUID?

    var decodedItems: [PlanItem] {
        guard let data = items.data(using: .utf8),
              let arr = try? JSONCoding.decoder.decode([PlanItem].self, from: data) else { return [] }
        return arr
    }

    var itemCount: Int {
        decodedItems.count
    }

    var exercisePreviewText: String {
        let names = decodedItems
            .sorted { $0.orderIndex < $1.orderIndex }
            .prefix(3)
            .map(\.displayExerciseName)
        return names.isEmpty ? "暂无动作" : names.joined(separator: "、")
    }

    var hasUnstartableItems: Bool {
        !PlanItem.unstartableItems(in: decodedItems).isEmpty
    }
}

/// Team 计划页卡片：最新不可变分享版本 + 最小化反馈统计。
struct TeamPlanShareCardDTO: Decodable, Identifiable, Hashable {
    var shareId: UUID
    var versionId: UUID
    var teamId: UUID
    var ownerUserId: UUID
    var ownerName: String?
    var sourcePlanId: UUID?
    var title: String
    var versionNumber: Int?
    var planNameSnapshot: String
    var mode: String?
    var items: String
    var createdAt: Date?
    var copyCount: Int?
    var completionCount: Int?
    var adoptionCount: Int?
    var weeklyCompletionCount: Int?

    var id: UUID { shareId }
    var displayCopyCount: Int { copyCount ?? adoptionCount ?? 0 }
    var displayCompletionCount: Int { completionCount ?? weeklyCompletionCount ?? 0 }

    var decodedItems: [PlanItem] {
        guard let data = items.data(using: .utf8),
              let arr = try? JSONCoding.decoder.decode([PlanItem].self, from: data) else { return [] }
        return arr
    }

    var planMode: WorkoutPlanMode {
        mode.flatMap(WorkoutPlanMode.init(rawValue:)) ?? .adaptive
    }

    var itemCount: Int { decodedItems.count }

    var exercisePreviewText: String {
        let names = decodedItems
            .sorted { $0.orderIndex < $1.orderIndex }
            .prefix(3)
            .map(\.displayExerciseName)
        return names.isEmpty ? "暂无动作" : names.joined(separator: "、")
    }

    var hasUnstartableItems: Bool {
        !PlanItem.unstartableItems(in: decodedItems).isEmpty
    }
}

struct TeamPlanShareVersionDTO: Decodable, Identifiable, Hashable {
    var id: UUID
    var shareId: UUID
    var versionNumber: Int?
    var planNameSnapshot: String
    var mode: String?
    var items: String
    var createdAt: Date?
}

struct TeamPlanShareEventDTO: Decodable, Identifiable, Hashable {
    var id: UUID
    var teamId: UUID
    var shareId: UUID
    var versionId: UUID
    var userId: UUID
    var eventType: String
    var workoutId: UUID?
    var eventDate: String?
    var createdAt: Date?
}

// MARK: - Team 请求体

struct CreateTeamRequest: Encodable { let name: String }
struct JoinTeamRequest: Encodable { let inviteCode: String }
struct ReactRequest: Encodable { let emoji: String }
struct UpdateTeamSharePreferenceRequest: Encodable { let autoShareWorkouts: Bool }
struct SharePlanRequest: Encodable {
    let sourcePlanId: UUID
    let planNameSnapshot: String?
    let items: String?
}
struct TeamPlanShareEventRequest: Encodable {
    let eventType: String
    let workoutId: UUID?
    let eventDate: String?
}

struct CheckInRequest: Encodable {
    let workoutId: UUID
    let checkinDate: String  // "yyyy-MM-dd"
    let summary: CheckinSummary
    let teamIds: [UUID]
}
