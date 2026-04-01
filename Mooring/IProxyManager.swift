//
//  IProxyManager.swift
//  Mooring
//
//  Created by cc on 05/03/26.
//

import Foundation
import Combine
import Darwin

#if canImport(Darwin)
import Darwin.POSIX
#endif

enum ConnectionType: String, CaseIterable, Identifiable {
    case usb = "USB"
    case network = "Network"

    var id: String { rawValue }

    var flag: String? {
        switch self {
        case .usb: return nil // default, no flag needed
        case .network: return "-n"
        }
    }
}

struct IProxyInstance: Identifiable, Equatable {
    let id: Int32 // pid
    let localPort: Int
    let devicePort: Int
    let udid: String?
    let connectionType: ConnectionType
    let sourceAddress: String?
}

class IProxyManager: ObservableObject {
    @Published var instances: [IProxyInstance] = []
    private var timer: Timer?

    /// Grouped instances by UDID (nil UDID grouped as "Unknown Device")
    var groupedByDevice: [(udid: String?, instances: [IProxyInstance])] {
        let grouped = Dictionary(grouping: instances) { $0.udid }
        // Sort: known UDIDs first (alphabetical), then unknown
        return grouped.sorted { lhs, rhs in
            switch (lhs.key, rhs.key) {
            case (nil, nil): return false
            case (nil, _): return false
            case (_, nil): return true
            case let (l?, r?): return l < r
            }
        }.map { (udid: $0.key, instances: $0.value) }
    }

    static var iproxyURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("libimobiledevice/bin/iproxy")
    }

    static var ideviceIdURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("libimobiledevice/bin/idevice_id")
    }

    @Published var availableUDIDs: [String] = []

    /// Run `idevice_id -l` to list connected device UDIDs.
    func refreshDeviceList() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let url = Self.ideviceIdURL,
                  FileManager.default.fileExists(atPath: url.path) else {
                return
            }

            let task = Process()
            task.executableURL = url
            task.arguments = ["-l"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = nil

            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                return
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return }

            let udids = output
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            DispatchQueue.main.async {
                self?.availableUDIDs = udids
            }
        }
    }

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var found: [IProxyInstance] = []

            var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
            var length: size_t = 0

            guard sysctl(&name, UInt32(name.count), nil, &length, nil, 0) == 0 else { return }

            let count = length / MemoryLayout<kinfo_proc>.stride
            var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)

            guard sysctl(&name, UInt32(name.count), &procs, &length, nil, 0) == 0 else { return }

            let actualCount = length / MemoryLayout<kinfo_proc>.stride

            for i in 0..<actualCount {
                let proc = procs[i]
                let pid = proc.kp_proc.p_pid

                if let arguments = self?.getProcessArguments(pid: pid),
                   !arguments.isEmpty,
                   arguments[0].hasSuffix("iproxy") || arguments[0] == "iproxy",
                   let instance = Self.parseArguments(pid: pid, arguments: Array(arguments.dropFirst())) {
                    found.append(instance)
                }
            }

            DispatchQueue.main.async {
                self?.instances = found
            }
        }
    }

    /// Parse iproxy CLI arguments into an IProxyInstance.
    /// Handles: iproxy [-u UDID] [-n|-l] [-s ADDR] [-d] LOCAL:DEVICE [...]
    /// Also handles legacy format: iproxy LOCAL DEVICE
    static func parseArguments(pid: Int32, arguments: [String]) -> IProxyInstance? {
        var udid: String?
        var connectionType: ConnectionType = .usb
        var sourceAddress: String?
        var positional: [String] = []
        var i = 0

        while i < arguments.count {
            let arg = arguments[i]
            switch arg {
            case "-u", "--udid":
                i += 1
                if i < arguments.count { udid = arguments[i] }
            case "-n", "--network":
                connectionType = .network
            case "-l", "--local":
                connectionType = .usb
            case "-s", "--source":
                i += 1
                if i < arguments.count { sourceAddress = arguments[i] }
            case "-d", "--debug", "-h", "--help", "-v", "--version":
                break // skip flags
            default:
                if !arg.hasPrefix("-") {
                    positional.append(arg)
                }
            }
            i += 1
        }

        // Try new format: LOCAL:DEVICE
        if let first = positional.first, first.contains(":") {
            let parts = first.split(separator: ":", maxSplits: 1)
            if parts.count == 2, let local = Int(parts[0]), let device = Int(parts[1]) {
                return IProxyInstance(id: pid, localPort: local, devicePort: device,
                                     udid: udid, connectionType: connectionType,
                                     sourceAddress: sourceAddress)
            }
        }

        // Legacy format: LOCAL DEVICE
        if positional.count >= 2,
           let local = Int(positional[0]),
           let device = Int(positional[1]) {
            return IProxyInstance(id: pid, localPort: local, devicePort: device,
                                 udid: udid, connectionType: connectionType,
                                 sourceAddress: sourceAddress)
        }

        return nil
    }

    private func getProcessArguments(pid: pid_t) -> [String]? {
        var name: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var length: size_t = 0

        guard sysctl(&name, UInt32(name.count), nil, &length, nil, 0) == 0 else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: length)

        guard sysctl(&name, UInt32(name.count), &buffer, &length, nil, 0) == 0 else {
            return nil
        }

        guard length >= MemoryLayout<Int32>.size else { return nil }

        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        guard argc > 0 else { return nil }

        var offset = MemoryLayout<Int32>.size

        // Skip the executable path
        while offset < length && buffer[offset] != 0 { offset += 1 }
        while offset < length && buffer[offset] == 0 { offset += 1 }

        var arguments: [String] = []
        var currentArg: [UInt8] = []

        while offset < length && arguments.count < argc {
            if buffer[offset] == 0 {
                if !currentArg.isEmpty {
                    if let arg = String(bytes: currentArg, encoding: .utf8) {
                        arguments.append(arg)
                    }
                    currentArg.removeAll()
                }
            } else {
                currentArg.append(buffer[offset])
            }
            offset += 1
        }

        if !currentArg.isEmpty, let arg = String(bytes: currentArg, encoding: .utf8) {
            arguments.append(arg)
        }

        return arguments.isEmpty ? nil : arguments
    }

    func kill(instance: IProxyInstance) {
        Foundation.kill(instance.id, SIGINT)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refresh()
        }
    }

    private func findAvailablePort() -> Int? {
        let sockfd = socket(AF_INET, SOCK_STREAM, 0)
        guard sockfd >= 0 else { return nil }
        defer { close(sockfd) }

        var reuseAddr: Int32 = 1
        setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(sockfd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { return nil }

        var assignedAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        let result = withUnsafeMutablePointer(to: &assignedAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                getsockname(sockfd, sockaddrPtr, &addrLen)
            }
        }
        guard result == 0 else { return nil }

        return Int(UInt16(bigEndian: assignedAddr.sin_port))
    }

    func create(localPort: Int, devicePort: Int, udid: String? = nil,
                connectionType: ConnectionType = .usb, sourceAddress: String? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let iproxyURL = Self.iproxyURL,
                  FileManager.default.fileExists(atPath: iproxyURL.path) else {
                print("iproxy not found in app bundle")
                return
            }

            let task = Process()
            task.executableURL = iproxyURL

            var args: [String] = []
            if let udid = udid, !udid.isEmpty {
                args += ["-u", udid]
            }
            if let flag = connectionType.flag {
                args.append(flag)
            }
            if let addr = sourceAddress, !addr.isEmpty {
                args += ["-s", addr]
            }
            args.append("\(localPort):\(devicePort)")

            task.arguments = args
            task.standardOutput = nil
            task.standardError = nil

            do {
                try task.run()
            } catch {
                print("Failed to launch iproxy: \(error)")
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.refresh()
            }
        }
    }

    func createWithRandomPort(devicePort: Int, udid: String? = nil,
                              connectionType: ConnectionType = .usb, sourceAddress: String? = nil) {
        guard let availablePort = findAvailablePort() else {
            print("Failed to find available port")
            return
        }
        create(localPort: availablePort, devicePort: devicePort, udid: udid,
               connectionType: connectionType, sourceAddress: sourceAddress)
    }
}
