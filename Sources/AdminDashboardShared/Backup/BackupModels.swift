
 // ~/workspace/AdminDashboard/Sources/AdminDashboardShared/BackupModels.swift

import Foundation

// MARK: - Backup Execution Status

public struct BackupExecutionStatus: Codable, Sendable, Equatable {
    public let state: String
    public let startedAt: String?
    public let completedAt: String?
    public let exitCode: Int?
    public let stdout: String?
    public let stderr: String?

    public init(
        state: String,
        startedAt: String?,
        completedAt: String?,
        exitCode: Int?,
        stdout: String?,
        stderr: String?
    ) {
        self.state = state
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }

    enum CodingKeys: String, CodingKey {
        case state
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case exitCode = "exit_code"
        case stdout
        case stderr
    }

    public var isRunning: Bool {
        state == "running"
    }
}

// MARK: - Backup Target

public struct BackupTarget: Codable, Sendable, Equatable {
    public let name: String
    public let handler: String
    public let status: String
    public let reason: String?

    public init(
        name: String,
        handler: String,
        status: String,
        reason: String?
    ) {
        self.name = name
        self.handler = handler
        self.status = status
        self.reason = reason
    }
}

// MARK: - Backup Report

public struct BackupReport: Codable, Sendable, Equatable {
    public let version: Int
    public let startedAt: String
    public let completedAt: String
    public let status: String
    public let targets: [BackupTarget]

    public init(
        version: Int,
        startedAt: String,
        completedAt: String,
        status: String,
        targets: [BackupTarget]
    ) {
        self.version = version
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.targets = targets
    }

    enum CodingKeys: String, CodingKey {
        case version
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case status
        case targets
    }
}

// MARK: - Backup Generation

public struct BackupGeneration: Codable, Sendable, Equatable {
    public let generation: String
    public let report: BackupReport

    public init(
        generation: String,
        report: BackupReport
    ) {
        self.generation = generation
        self.report = report
    }
}

// MARK: - Backup History

public struct BackupHistoryEntry: Codable, Sendable, Equatable {
    public let runId: String?
    public let startedAt: String
    public let completedAt: String?
    public let executionState: String
    public let exitCode: Int?
    public let status: String?
    public let targets: [BackupTarget]?
    public let reportStartedAt: String?
    public let reportCompletedAt: String?
    public let error: String?

    public init(
        runId: String?,
        startedAt: String,
        completedAt: String?,
        executionState: String,
        exitCode: Int?,
        status: String?,
        targets: [BackupTarget]?,
        reportStartedAt: String?,
        reportCompletedAt: String?,
        error: String?
    ) {
        self.runId = runId
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.executionState = executionState
        self.exitCode = exitCode
        self.status = status
        self.targets = targets
        self.reportStartedAt = reportStartedAt
        self.reportCompletedAt = reportCompletedAt
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case runId = "run_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case executionState = "execution_state"
        case exitCode = "exit_code"
        case status
        case targets
        case reportStartedAt = "report_started_at"
        case reportCompletedAt = "report_completed_at"
        case error
    }
}

public struct BackupHistory: Codable, Sendable, Equatable {
    public let entries: [BackupHistoryEntry]

    public init(entries: [BackupHistoryEntry]) {
        self.entries = entries
    }
}

// MARK: - Backup Start Response

public struct BackupStartResponse: Codable, Sendable, Equatable {
    public let state: String
    public let startedAt: String

    public init(
        state: String,
        startedAt: String
    ) {
        self.state = state
        self.startedAt = startedAt
    }

    enum CodingKeys: String, CodingKey {
        case state
        case startedAt = "started_at"
    }
}
