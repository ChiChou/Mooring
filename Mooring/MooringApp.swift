//
//  MooringApp.swift
//  Mooring
//
//  Created by cc on 05/03/26.
//

import SwiftUI
import AppKit

@main
struct MooringApp: App {
    @StateObject private var proxyManager = IProxyManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Mooring", systemImage: "cable.connector") {
            MenuBarView()
                .environmentObject(proxyManager)
        }
        .menuBarExtraStyle(.window)
        
        Window("New iproxy Instance", id: "add-proxy") {
            AddProxySheet()
                .environmentObject(proxyManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        
        // Fetch all running applications with your bundle ID
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        
        // If there is more than 1 running, another instance is already active
        if runningApps.count > 1 {
            print("Another instance is already running. Terminating.")
            exit(0)
        }
    }
}

