import AppKit
import Darwin

/// Process table helpers, used to find coding agents running inside a
/// terminal and the terminal app hosting an agent session.
enum ProcessTree {
    struct Entry {
        let pid: pid_t
        let parent: pid_t
        let name: String
    }

    static func snapshot() -> [Entry] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return [] }
        let stride = MemoryLayout<kinfo_proc>.stride
        // The table can grow between the two calls.
        size += stride * 32
        var processes = [kinfo_proc](repeating: kinfo_proc(), count: size / stride)
        guard sysctl(&mib, 4, &processes, &size, nil, 0) == 0 else { return [] }
        return processes.prefix(size / stride).map { info in
            let name = withUnsafeBytes(of: info.kp_proc.p_comm) { raw in
                String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
            }
            return Entry(pid: info.kp_proc.p_pid, parent: info.kp_eproc.e_ppid, name: name)
        }
    }

    static func descendants(of root: pid_t, in entries: [Entry], maxDepth: Int = 8) -> [Entry] {
        var children: [pid_t: [Entry]] = [:]
        for entry in entries { children[entry.parent, default: []].append(entry) }
        var result: [Entry] = []
        var frontier = [root]
        for _ in 0..<maxDepth where !frontier.isEmpty {
            let next = frontier.flatMap { children[$0] ?? [] }
            result += next
            frontier = next.map(\.pid)
        }
        return result
    }

    /// Command line arguments, including a title the process set for itself.
    static func arguments(of pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return [] }

        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        // Skip the executable path and the padding after it.
        while index < size, buffer[index] != 0 { index += 1 }
        while index < size, buffer[index] == 0 { index += 1 }

        var arguments: [String] = []
        while index < size, arguments.count < argc {
            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            arguments.append(String(decoding: buffer[start..<index], as: UTF8.self))
            index += 1
        }
        return arguments
    }

    static func isAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    /// The first GUI app among the given processes, e.g. the terminal hosting an agent.
    @MainActor
    static func app(among pids: [pid_t]) -> NSRunningApplication? {
        for pid in pids {
            if let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular {
                return app
            }
        }
        return nil
    }
}
