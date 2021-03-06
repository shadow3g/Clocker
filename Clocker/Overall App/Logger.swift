// Copyright © 2015 Abhishek Banthia

import Cocoa
import os
import os.log
import os.signpost

class Logger: NSObject {
    let logObjc = OSLog(subsystem: "com.abhishek.Clocker", category: "app")

    class func log(object annotations: [String: Any]?, for event: NSString) {
        if #available(OSX 10.14, *) {
            os_log(.default, "[%@] - [%@]", event, annotations ?? [:])
        }
    }

    class func info(_ message: String) {
        if #available(OSX 10.14, *) {
            os_log(.info, "%@", message)
        }
    }
}

@available(OSX 10.14, *)
class PerfLogger: NSObject {
    static var panelLog = OSLog(subsystem: "com.abhishek.Clocker",
                                category: "Open Panel")
    static let signpostID = OSSignpostID(log: panelLog)

    class func disable() {
        panelLog = .disabled
    }

    class func startMarker(_ name: StaticString) {
        os_signpost(.begin,
                    log: panelLog,
                    name: name,
                    signpostID: signpostID)
    }

    class func endMarker(_ name: StaticString) {
        os_signpost(.end,
                    log: panelLog,
                    name: name,
                    signpostID: signpostID)
    }
}
