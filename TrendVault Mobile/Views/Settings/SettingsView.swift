//
//  SettingsView.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 16.12.25.
//

import SwiftUI

struct SettingsView: View {

    @Environment(LocalStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {

                Section("OCR") {
                    Toggle("Enable OCR", isOn: Binding(
                        get: { store.isOCREnabled },
                        set: { store.isOCREnabled = $0 }
                    ))

                    Text("OCR is used for search and tag suggestions. It is never applied automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Default Tag") {
                    TextField(
                        "Default tag for imports",
                        text: Binding(
                            get: { store.defaultImportTag },
                            set: { store.defaultImportTag = $0 }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                    Text("Used when importing screenshots from Photos. Empty input falls back to \"inbox\".")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    NavigationLink("About TrendVault", destination: AboutView())
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(LocalStore())
}
