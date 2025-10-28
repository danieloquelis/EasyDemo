//
//  SetupView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI

/// Main setup view orchestrating window selection, background choice, and preview
struct SetupView: View {
    @State private var selectedWindow: WindowInfo?
    @State private var selectedBackground: BackgroundStyle = .solidColor(.black)
    @State private var showingWindowSelector = true

    var body: some View {
        NavigationSplitView {
            // Sidebar with setup options
            setupSidebar
                .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 400)
        } detail: {
            // Main preview area
            if let window = selectedWindow {
                WindowPreviewView(
                    window: window,
                    backgroundStyle: selectedBackground
                )
                .navigationTitle("Preview")
            } else {
                emptyPreviewState
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    @ViewBuilder
    private var setupSidebar: some View {
        List {
            Section("Window Selection") {
                if let window = selectedWindow {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(window.displayName)
                                .font(.headline)

                            Text("\(Int(window.bounds.width)) × \(Int(window.bounds.height))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Change") {
                            showingWindowSelector = true
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Button("Select Window") {
                        showingWindowSelector = true
                    }
                }
            }

            if selectedWindow != nil {
                Section("Background") {
                    BackgroundSelectionView(selectedBackground: $selectedBackground)
                }

                Section("Actions") {
                    Button {
                        // TODO: Start recording
                    } label: {
                        Label("Start Recording", systemImage: "record.circle")
                    }
                    .disabled(selectedWindow == nil)
                }
            }
        }
        .navigationTitle("Setup")
        .sheet(isPresented: $showingWindowSelector) {
            WindowSelectorSheet(selectedWindow: $selectedWindow)
        }
    }

    private var emptyPreviewState: some View {
        VStack(spacing: 20) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Select a window to preview")
                .font(.title2)
                .foregroundColor(.secondary)

            Button("Choose Window") {
                showingWindowSelector = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

/// Sheet for window selection
struct WindowSelectorSheet: View {
    @Binding var selectedWindow: WindowInfo?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WindowSelectionViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Window")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Window list
            WindowSelectionView()
                .environmentObject(viewModel)

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Select") {
                    selectedWindow = viewModel.selectedWindow
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.selectedWindow == nil)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 700, height: 500)
    }
}

#Preview {
    SetupView()
}
