import Foundation
import SwiftData
import AltusKit

@Model
final class Exercise {
    var name: String
    var categoryRaw: String

    var category: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(name: String, category: ExerciseCategory) {
        self.name = name
        self.categoryRaw = category.rawValue
    }
}

@Model
final class JumpTest {
    var id: UUID
    var date: Date
    var hangTimeMs: Double
    var jumpHeightCm: Double
    var modeRaw: String
    var confidence: Double

    var mode: JumpMode {
        get { JumpMode(rawValue: modeRaw) ?? .guided }
        set { modeRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), date: Date = Date(), result: JumpResult) {
        self.id = id
        self.date = date
        self.hangTimeMs = result.hangTime * 1000
        self.jumpHeightCm = result.jumpHeightCm
        self.modeRaw = result.mode.rawValue
        self.confidence = result.confidence
    }
}

@Model
final class LiftSet {
    var id: UUID
    var date: Date
    @Relationship var exercise: Exercise?
    var targetLoadKg: Double?
    @Relationship(deleteRule: .cascade) var reps: [Rep] = []

    init(id: UUID = UUID(), date: Date = Date(), exercise: Exercise?, targetLoadKg: Double? = nil) {
        self.id = id
        self.date = date
        self.exercise = exercise
        self.targetLoadKg = targetLoadKg
    }
}

@Model
final class Rep {
    var index: Int
    var meanConcentricVelocityMps: Double
    var peakVelocityMps: Double
    var concentricDurationMs: Double
    var velocityLossPercent: Double
    var estimatedRIR: Int?

    init(result: RepResult, estimatedRIR: Int?) {
        self.index = result.index
        self.meanConcentricVelocityMps = result.meanConcentricVelocityMps
        self.peakVelocityMps = result.peakVelocityMps
        self.concentricDurationMs = result.concentricDuration * 1000
        self.velocityLossPercent = result.velocityLossPercent
        self.estimatedRIR = estimatedRIR
    }
}
