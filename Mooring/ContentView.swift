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

struct CreateProxyForm: View {
    @EnvironmentObject var proxyManager: IProxyManager
    var onDismiss: () -> Void

    @State private var devicePort: String = ""
    @State private var localPort: String = ""
    @State private var useRandomPort: Bool = false
    @State private var userEditedLocal = false
    @State private var udid: String = ""
    @State private var connectionType: ConnectionType = .usb
    @FocusState private var focusedField: Field?

    enum Field {
        case devicePort
        case localPort
        case udid
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("New iproxy Instance")
                    .font(.headline)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device Port")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. 2222", text: $devicePort)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .devicePort)
                        .onChange(of: devicePort) { _, newValue in
                            if !userEditedLocal && !useRandomPort {
                                localPort = newValue
                            }
                        }
                }

                if !useRandomPort {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                        .padding(.top, 18)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Local Port")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. 2222", text: $localPort)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .localPort)
                            .onChange(of: localPort) { _, newValue in
                                if newValue != devicePort {
                                    userEditedLocal = true
                                }
                            }
                    }
                }
            }

            Toggle("Use random local port", isOn: $useRandomPort)
                .toggleStyle(.checkbox)
                .font(.caption)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UDID (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("All devices", text: $udid)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .udid)
                }
            }

            Picker("Connection", selection: $connectionType) {
                ForEach(ConnectionType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    guard let dev = Int(devicePort), dev > 0, dev <= 65535 else { return }
                    let trimmedUdid = udid.trimmingCharacters(in: .whitespaces)

                    if useRandomPort {
                        proxyManager.createWithRandomPort(
                            devicePort: dev,
                            udid: trimmedUdid.isEmpty ? nil : trimmedUdid,
                            connectionType: connectionType)
                    } else {
                        guard let loc = Int(localPort), loc > 0, loc <= 65535 else { return }
                        proxyManager.create(
                            localPort: loc, devicePort: dev,
                            udid: trimmedUdid.isEmpty ? nil : trimmedUdid,
                            connectionType: connectionType)
                    }

                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(devicePort.isEmpty || (!useRandomPort && localPort.isEmpty))
            }
        }
        .onAppear {
            focusedField = .devicePort
        }
    }
}

struct InstanceRow: View {
    @EnvironmentObject var proxyManager: IProxyManager
    let instance: IProxyInstance

    var body: some View {
        HStack {
            Image(systemName: instance.connectionType == .network ? "wifi" : "cable.connector")
            Text("\(instance.localPort, format: .number.grouping(.never)) : \(instance.devicePort, format: .number.grouping(.never))")
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
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

struct MenuBarView: View {
    @EnvironmentObject var proxyManager: IProxyManager
    @State private var showCreateForm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !showCreateForm {
                Button {
                    showCreateForm = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New iproxy")
                        Spacer()
                        Text("\u{2318}N")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .menuItemStyle()
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: .command)
                .padding(.top, 6)
            } else {
                CreateProxyForm {
                    showCreateForm = false
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
                let groups = proxyManager.groupedByDevice
                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    // Device header
                    HStack(spacing: 4) {
                        Image(systemName: "iphone")
                            .font(.caption2)
                        if let udid = group.udid {
                            Text(udid.prefix(12) + "...")
                                .font(.caption)
                                .help(udid)
                        } else {
                            Text("Any Device")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                    ForEach(group.instances) { instance in
                        InstanceRow(instance: instance)
                    }
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
                    Text("\u{2318}Q")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .menuItemStyle()
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
            .padding(.bottom, 6)
        }
        .frame(width: 280)
    }
}

struct AddProxySheet: View {
    @EnvironmentObject var proxyManager: IProxyManager
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        CreateProxyForm {
            dismissWindow(id: "add-proxy")
        }
        .padding(20)
        .frame(width: 380)
    }
}
