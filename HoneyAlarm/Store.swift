import Foundation
import SwiftData

/// 统一的 SwiftData 容器与查询入口。
@available(iOS 17, *)
public final class Store {
    public static let shared = Store()

    public let container: ModelContainer

    public init() {
        let schema = Schema([
            Alarm.self,
            TimerModel.self,
            Ringtone.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("无法创建 SwiftData 容器: \(error)")
        }
    }

    @MainActor
    public var context: ModelContext {
        container.mainContext
    }
}