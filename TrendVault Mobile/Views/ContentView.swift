//
//  ContentView.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 14.12.25.
//

import SwiftUI

struct ContentView: View {

    @Bindable var store: LocalStore

    var body: some View {
        NavigationStack {
            List {
                Section("Items") {
                    if store.items.isEmpty {
                        Text("No items yet.")
                    } else {
                        ForEach(store.items) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.tags.isEmpty ? "Untitled" : item.tags.joined(separator: ", "))
                                    .font(.headline)
                                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { indexSet in
                            for idx in indexSet {
                                store.delete(id: store.items[idx].id)
                            }
                        }
                    }
                }

                Section("Debug") {
                    Button("Add sample item") {
                        let sample = TrendItem(tags: ["ad", "hook"], source: "debug")
                        store.add(sample)
                    }

                    Button("Reload from disk") {
                        store.reload()
                    }
                }
            }
            .navigationTitle("TrendVault")
        }
    }
}

#Preview {
    ContentView(store: LocalStore())
}
