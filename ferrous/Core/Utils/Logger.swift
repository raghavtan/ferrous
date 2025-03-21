import Foundation
import os.log

final class FerrousLogger {
    static let shared = FerrousLogger()
    
    let app = OSLog(subsystem: "com.onefootball.ferrous", category: "app")
    let network = OSLog(subsystem: "com.onefootball.ferrous", category: "network")
    let kubernetes = OSLog(subsystem: "com.onefootball.ferrous", category: "kubernetes")
    let github = OSLog(subsystem: "com.onefootball.ferrous", category: "github")
    let tools = OSLog(subsystem: "com.onefootball.ferrous", category: "tools")
    
    private init() {}
}

// Extension with helper methods
extension FerrousLogger {
    func debug(_ message: String, log: OSLog) {
        os_log("%{public}@", log: log, type: .debug, message)
    }
    
    func info(_ message: String, log: OSLog) {
        os_log("%{public}@", log: log, type: .info, message)
    }
    
    func warning(_ message: String, log: OSLog) {
        os_log("%{public}@", log: log, type: .default, message)
    }
    
    func error(_ message: String, log: OSLog) {
        os_log("%{public}@", log: log, type: .error, message)
    }
    
    // Static accessors for convenience
    static var app: OSLog { shared.app }
    static var network: OSLog { shared.network }
    static var kubernetes: OSLog { shared.kubernetes }
    static var github: OSLog { shared.github }
    static var tools: OSLog { shared.tools }
}
