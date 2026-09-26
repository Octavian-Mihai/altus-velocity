import SwiftData

extension ModelContainer {
    static func makeAltusContainer() -> ModelContainer {
        let schema = Schema([Exercise.self, JumpTest.self, LiftSet.self, Rep.self])
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create Altus SwiftData container: \(error)")
        }
    }
}
