import Foundation

nonisolated enum PortScanner {

    static func scan() -> [PortProcess] {
        allPIDs()
            .compactMap(process)
            .sorted { ($0.ports.first?.port ?? 0) < ($1.ports.first?.port ?? 0) }
    }

    private static func process(_ pid: pid_t) -> PortProcess? {
        let ports = listeningPorts(of: pid)
        guard !ports.isEmpty else { return nil }

        let path = executablePath(of: pid)
        let arguments = arguments(of: pid)
        // argv[0] reads nicer than the binary (x lives at …/versions/2.1.0),
        // unless the process rewrote it into a title like `redis-server 127.0.0.1:6379`
        let command = arguments.first.flatMap { arg in
            !arg.contains(" ") || FileManager.default.fileExists(atPath: arg) ? arg : nil
        }
        let name = (command ?? path).map { ($0 as NSString).lastPathComponent }

        return PortProcess(
            pid: pid,
            name: name ?? "pid \(pid)",
            path: path,
            cwd: workingDirectory(of: pid),
            arguments: arguments,
            startedAt: startDate(of: pid),
            ports: ports
        )
    }

    // MARK: - PIDs & sockets

    private static func allPIDs() -> [pid_t] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }

        // some room in case something spawns in between
        var pids = [pid_t](repeating: 0, count: Int(estimate) * 2)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        return Array(pids.prefix(Int(max(count, 0))))
    }

    private static func listeningPorts(of pid: pid_t) -> [ListeningPort] {
        // 0 for stuff we don't own, like root's processes
        let bufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard bufferSize > 0 else { return [] }

        let stride = MemoryLayout<proc_fdinfo>.stride
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(bufferSize) / stride)
        let filled = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, bufferSize)
        guard filled > 0 else { return [] }

        let ports = fds.prefix(Int(filled) / stride)
            .filter { $0.proc_fdtype == PROX_FDTYPE_SOCKET }
            .compactMap { listeningPort(pid: pid, fd: $0.proc_fd) }

        return Set(ports).sorted { ($0.port, $0.address) < ($1.port, $1.address) }
    }

    private static func listeningPort(pid: pid_t, fd: Int32) -> ListeningPort? {
        var info = socket_fdinfo()
        let size = Int32(MemoryLayout<socket_fdinfo>.size)
        guard proc_pidfdinfo(pid, fd, PROC_PIDFDSOCKETINFO, &info, size) == size else { return nil }

        let socket = info.psi
        let tcp = socket.soi_proto.pri_tcp
        guard socket.soi_kind == SOCKINFO_TCP, tcp.tcpsi_state == TSI_S_LISTEN else { return nil }

        let inet = tcp.tcpsi_ini
        // network byte order, tucked in the low 16 bits
        let port = UInt16(bigEndian: UInt16(truncatingIfNeeded: inet.insi_lport))

        let address: String
        switch socket.soi_family {
        case AF_INET:
            var addr = inet.insi_laddr.ina_46.i46a_addr4
            address = string(from: &addr, family: AF_INET)
        case AF_INET6:
            var addr = inet.insi_laddr.ina_6
            address = string(from: &addr, family: AF_INET6)
        default:
            return nil
        }

        return ListeningPort(port: port, address: address)
    }

    private static func string(from address: UnsafeRawPointer, family: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        guard inet_ntop(family, address, &buffer, socklen_t(buffer.count)) != nil else { return "?" }
        return String(nulTerminated: buffer)
    }

    // MARK: - Process details

    private static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(nulTerminated: buffer)
    }

    private static func workingDirectory(of pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }

        let path = withUnsafeBytes(of: info.pvi_cdir.vip_path) { raw in
            String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
        }
        return path.isEmpty ? nil : path
    }

    private static func startDate(of pid: pid_t) -> Date? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }

        let seconds = TimeInterval(info.pbi_start_tvsec) + TimeInterval(info.pbi_start_tvusec) / 1_000_000
        return Date(timeIntervalSince1970: seconds)
    }

    // KERN_PROCARGS2 hands back: argc, exec path, some NULs, argv, then env
    private static func arguments(of pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return [] }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0,
              size > MemoryLayout<Int32>.size else { return [] }

        let argc = Int(buffer.withUnsafeBytes { $0.load(as: Int32.self) })
        let argv = buffer[MemoryLayout<Int32>.size..<size]
            .drop { $0 != 0 } // exec path
            .drop { $0 == 0 } // padding

        // title-rewriters leave blank fields, so take exactly argc and toss the empties
        return argv
            .split(separator: 0, maxSplits: argc, omittingEmptySubsequences: false)
            .prefix(argc)
            .filter { !$0.isEmpty }
            .map { String(decoding: $0, as: UTF8.self) }
    }
}

nonisolated private extension String {
    init(nulTerminated buffer: [CChar]) {
        self.init(decoding: buffer.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
    }
}
