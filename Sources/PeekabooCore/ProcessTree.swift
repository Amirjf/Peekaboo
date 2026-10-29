import Darwin
import Foundation

/// Small helpers for finding the Claude process behind a hook call.
public enum ProcessTree {
    public struct Info {
        public var ppid: pid_t
        public var name: String
        public var tdev: dev_t
    }

    public static func info(_ pid: pid_t) -> Info? {
        var kp = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &kp, &size, nil, 0) == 0, size > 0 else { return nil }
        let name = withUnsafePointer(to: &kp.kp_proc.p_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) { String(cString: $0) }
        }
        return Info(ppid: kp.kp_eproc.e_ppid, name: name, tdev: kp.kp_eproc.e_tdev)
    }

    /// Walks up past any shells that wrapped the hook and returns the first real parent (Claude itself).
    public static func claudeAncestor() -> (pid: pid_t, tty: String?) {
        let shells: Set<String> = ["sh", "bash", "zsh", "dash", "fish", "env", "peekaboo-hook"]
        var pid = getppid()
        for _ in 0..<8 {
            guard let i = info(pid) else { break }
            let name = i.name.hasPrefix("-") ? String(i.name.dropFirst()) : i.name
            if !shells.contains(name) {
                return (pid, ttyPath(i.tdev))
            }
            pid = i.ppid
        }
        return (getppid(), nil)
    }

    static func ttyPath(_ dev: dev_t) -> String? {
        guard dev != -1, let name = devname(dev, S_IFCHR) else { return nil }
        let s = String(cString: name)
        return s.isEmpty || s == "??" ? nil : "/dev/" + s
    }

    public static func isAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}
