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

struct IProxyInstance: Identifiable, Equatable {
    let id: Int32 // pid
    let sourcePort: Int
    let destinationPort: Int
}

class IProxyManager: ObservableObject {
    @Published var instances: [IProxyInstance] = []
    private var timer: Timer?

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
            
            // Get all running processes
            var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
            var length: size_t = 0
            
            // Get the size needed
            guard sysctl(&name, UInt32(name.count), nil, &length, nil, 0) == 0 else {
                return
            }
            
            // Allocate buffer
            let count = length / MemoryLayout<kinfo_proc>.stride
            var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
            
            // Get the process list
            guard sysctl(&name, UInt32(name.count), &procs, &length, nil, 0) == 0 else {
                return
            }
            
            let actualCount = length / MemoryLayout<kinfo_proc>.stride
            
            // Check each process
            for i in 0..<actualCount {
                let proc = procs[i]
                let pid = proc.kp_proc.p_pid
                
                // Get process arguments
                if let arguments = self?.getProcessArguments(pid: pid),
                   arguments.count >= 3,
                   arguments[0].hasSuffix("iproxy") || arguments[0] == "iproxy" {
                    
                    // Parse: iproxy <source_port> <destination_port>
                    if let sourcePort = Int(arguments[1]),
                       let destPort = Int(arguments[2]) {
                        found.append(IProxyInstance(id: pid, sourcePort: sourcePort, destinationPort: destPort))
                    }
                }
            }
            
            DispatchQueue.main.async {
                self?.instances = found
            }
        }
    }
    
    private func getProcessArguments(pid: pid_t) -> [String]? {
        var name: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var length: size_t = 0
        
        // Get the size needed
        guard sysctl(&name, UInt32(name.count), nil, &length, nil, 0) == 0 else {
            return nil
        }
        
        // Allocate buffer
        var buffer = [UInt8](repeating: 0, count: length)
        
        // Get the arguments
        guard sysctl(&name, UInt32(name.count), &buffer, &length, nil, 0) == 0 else {
            return nil
        }
        
        // Parse the buffer
        // First 4 bytes is argc (argument count)
        guard length >= MemoryLayout<Int32>.size else { return nil }
        
        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        guard argc > 0 else { return nil }
        
        // Skip argc and find the start of arguments
        var offset = MemoryLayout<Int32>.size
        
        // Skip the executable path (null-terminated)
        while offset < length && buffer[offset] != 0 {
            offset += 1
        }
        
        // Skip null bytes
        while offset < length && buffer[offset] == 0 {
            offset += 1
        }
        
        // Parse arguments (null-separated strings)
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
        
        // Add the last argument if it exists
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
        // Create a socket
        let sockfd = socket(AF_INET, SOCK_STREAM, 0)
        guard sockfd >= 0 else {
            return nil
        }
        
        defer {
            close(sockfd)
        }
        
        // Enable address reuse
        var reuseAddr: Int32 = 1
        setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))
        
        // Bind to port 0 to let the OS assign an available port
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0  // Port 0 means "assign me any available port"
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(sockfd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult == 0 else {
            return nil
        }
        
        // Get the port that was assigned
        var assignedAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let getsocknameResult = withUnsafeMutablePointer(to: &assignedAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                getsockname(sockfd, sockaddrPtr, &addrLen)
            }
        }
        
        guard getsocknameResult == 0 else {
            return nil
        }
        
        let port = Int(UInt16(bigEndian: assignedAddr.sin_port))
        return port
    }

    func create(sourcePort: Int, destinationPort: Int) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            
            // Try common iproxy locations
            let possiblePaths = [
                "/usr/local/bin/iproxy",
                "/opt/homebrew/bin/iproxy",
                "/usr/bin/iproxy"
            ]
            
            var iproxyPath: String?
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path) {
                    iproxyPath = path
                    break
                }
            }
            
            guard let path = iproxyPath else {
                print("iproxy not found in common locations")
                return
            }
            
            task.executableURL = URL(fileURLWithPath: path)
            task.arguments = [String(sourcePort), String(destinationPort)]
            task.standardOutput = nil
            task.standardError = nil

            do {
                try task.run()
                // Don't wait - let it run in background
            } catch {
                print("Failed to launch iproxy: \(error)")
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.refresh()
            }
        }
    }
    
    func createWithRandomPort(sourcePort: Int) {
        guard let availablePort = findAvailablePort() else {
            print("Failed to find available port")
            return
        }
        
        create(sourcePort: sourcePort, destinationPort: availablePort)
    }
}
