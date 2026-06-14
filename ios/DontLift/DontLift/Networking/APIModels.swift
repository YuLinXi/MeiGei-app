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

/// 删号影响面（GET /account/deletion-impact）。
struct DeletionImpactDTO: Decodable {
    let ownedTeams: Int
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

/// 上传结果：已落库 id + 冲突 + 服务端时间。
struct SyncPushResult<T: Decodable>: Decodable {
    let applied: [UUID]
    let conflicts: [SyncConflict<T>]
    let serverTime: Date
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

struct WorkoutPlanDTO: Codable {
    var id: UUID
    var userId: UUID?
    var name: String
    /// 注意：后端 items 是 jsonb **字符串**，非数组。
    var items: String
    var forkedFrom: UUID?
    var sharedToTeamId: UUID?
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
}

struct WorkoutSetDTO: Codable {
    var id: UUID
    var workoutExerciseId: UUID?
    var setIndex: Int
    var weightKg: Double?
    var reps: Int?
    var completed: Bool?
    var note: String?
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
}

struct TeamMemberDTO: Decodable, Identifiable, Hashable {
    var id: UUID
    var teamId: UUID
    var userId: UUID
    var role: String        // owner | member
    var joinedAt: Date?
    /// 后端 join app_user.display_name 得到；用户未设名时为 nil，前端兜底。
    var displayName: String?
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

    /// 解析嵌套快照；坏数据时给空摘要兜底。
    var parsedSummary: CheckinSummary {
        guard let data = summary.data(using: .utf8),
              let s = try? JSONCoding.decoder.decode(CheckinSummary.self, from: data) else {
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

/// 服务端计划模板（Team 内浏览/Fork 用，items 同为 jsonb 字符串）。
struct ServerPlanDTO: Decodable, Identifiable, Hashable {
    var id: UUID
    var userId: UUID?
    var name: String
    var items: String
    var forkedFrom: UUID?
    var sharedToTeamId: UUID?

    var itemCount: Int {
        guard let data = items.data(using: .utf8),
              let arr = try? JSONCoding.decoder.decode([PlanItem].self, from: data) else { return 0 }
        return arr.count
    }
}

// MARK: - Team 请求体

struct CreateTeamRequest: Encodable { let name: String }
struct JoinTeamRequest: Encodable { let inviteCode: String }
struct ReactRequest: Encodable { let emoji: String }

struct CheckInRequest: Encodable {
    let workoutId: UUID
    let checkinDate: String  // "yyyy-MM-dd"
    let summary: CheckinSummary
}
