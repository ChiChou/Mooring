//
//  ContentView.swift
//  Mooring
//
//  Created by cc on 05/03/26.
//

import SwiftUI

struct MenuItemStyle: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
            )
            .padding(.horizontal, 4)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func menuItemStyle() -> some View {
        modifier(MenuItemStyle())
    }
}

struct MenuBarView: View {
    @EnvironmentObject var proxyManager: IProxyManager
    @State private var showCreateForm = false
    @State private var sourcePort: String = ""
    @State private var destinationPort: String = ""
    @State private var useRandomPort: Bool = false
    @State private var userEditedDestination = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case source
        case destination
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !showCreateForm {
                Button {
                    showCreateForm = true
                    focusedField = .source
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New iproxy")
                        Spacer()
                        Text("⌘N")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .menuItemStyle()
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: .command)
                .padding(.top, 6)
            } else {
                // Inline create form
                VStack(spacing: 12) {
                    HStack {
                        Text("New iproxy Instance")
                            .font(.headline)
                        Spacer()
                        Button {
                            showCreateForm = false
                            resetForm()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Source (device)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("e.g. 2222", text: $sourcePort)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .source)
                                .onChange(of: sourcePort) { _, newValue in
                                    if !userEditedDestination && !useRandomPort {
                                        destinationPort = newValue
                                    }
                                }
                        }
                        
                        if !useRandomPort {
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                                .padding(.top, 18)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Destination (local)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("e.g. 2222", text: $destinationPort)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .destination)
                                    .onChange(of: destinationPort) { _, newValue in
                                        if newValue != sourcePort {
                                            userEditedDestination = true
                                        }
                                    }
                            }
                        }
                    }
                    
                    Toggle("Use random destination port", isOn: $useRandomPort)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    
                    HStack(spacing: 8) {
                        Button("Cancel") {
                            showCreateForm = false
                            resetForm()
                        }
                        .keyboardShortcut(.cancelAction)
                        
                        Spacer()
                        
                        Button("Create") {
                            guard let src = Int(sourcePort), src > 0, src <= 65535 else { return }
                            
                            if useRandomPort {
                                proxyManager.createWithRandomPort(sourcePort: src)
                            } else {
                                guard let dst = Int(destinationPort), dst > 0, dst <= 65535 else { return }
                                proxyManager.create(sourcePort: src, destinationPort: dst)
                            }
                            
                            showCreateForm = false
                            resetForm()
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(sourcePort.isEmpty || (!useRandomPort && destinationPort.isEmpty))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .padding(.horizontal, 8)
                .padding(.top, 6)
            }

            Divider().padding(.horizontal, 8)

            // Section header
            Text("Running Instances")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 4)

            if proxyManager.instances.isEmpty {
                Text("No iproxy instances")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            } else {
                ForEach(proxyManager.instances) { instance in
                    HStack {
                        Image(systemName: "cable.connector")
                        Text("\(instance.sourcePort, format: .number.grouping(.never)) → \(instance.destinationPort, format: .number.grouping(.never))")
                            .fontWeight(.medium)
                        Spacer()
                        Text(verbatim: "pid \(instance.id)")
                            .font(.caption)
                            .opacity(0.5)
                        Button {
                            proxyManager.kill(instance: instance)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .menuItemStyle()
                }
            }

            Divider().padding(.horizontal, 8)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit")
                    Spacer()
                    Text("⌘Q")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .menuItemStyle()
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
            .padding(.bottom, 6)
        }
        .frame(width: 260)
    }
    
    private func resetForm() {
        sourcePort = ""
        destinationPort = ""
        useRandomPort = false
        userEditedDestination = false
    }
}

struct AddProxySheet: View {
    @EnvironmentObject var proxyManager: IProxyManager
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var sourcePort: String = ""
    @State private var destinationPort: String = ""
    @State private var useRandomPort: Bool = false
    @State private var userEditedDestination = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case source
        case destination
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("New iproxy Instance")
                .font(.headline)

            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Source (device)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. 2222", text: $sourcePort)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .source)
                        .onChange(of: sourcePort) { _, newValue in
                            if !userEditedDestination && !useRandomPort {
                                destinationPort = newValue
                            }
                        }
                }

                if !useRandomPort {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)

                    VStack(alignment: .leading) {
                        Text("Destination (local)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. 2222", text: $destinationPort)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .destination)
                            .onChange(of: destinationPort) { _, newValue in
                                if newValue != sourcePort {
                                    userEditedDestination = true
                                }
                            }
                    }
                }
            }

            Toggle("Use random destination port", isOn: $useRandomPort)
                .toggleStyle(.checkbox)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismissWindow(id: "add-proxy")
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    guard let src = Int(sourcePort), src > 0, src <= 65535 else { return }
                    
                    if useRandomPort {
                        proxyManager.createWithRandomPort(sourcePort: src)
                    } else {
                        guard let dst = Int(destinationPort), dst > 0, dst <= 65535 else { return }
                        proxyManager.create(sourcePort: src, destinationPort: dst)
                    }
                    
                    dismissWindow(id: "add-proxy")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            focusedField = .source
        }
    }
}
