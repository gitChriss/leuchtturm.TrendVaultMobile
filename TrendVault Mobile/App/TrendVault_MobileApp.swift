//
//  TrendVault_MobileApp.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 14.12.25.
//

import SwiftUI

@main
struct TrendVault_MobileApp: App {

    @State private var store = LocalStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .environment(store)
        }
    }
}
