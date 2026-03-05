//
//  MooringApp.swift
//  Mooring
//
//  Created by cc on 05/03/26.
//

import SwiftUI

@main
struct MooringApp: App {
    @StateObject private var proxyManager = IProxyManager()
    
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
