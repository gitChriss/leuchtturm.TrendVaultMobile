//
//  AboutView.swift
//  TrendVault Mobile
//
//  Created by Christian Ruppelt on 16.12.25.
//

import SwiftUI

struct AboutView: View {

    private var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
        ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
        ?? "TrendVault Mobile"
    }

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "?"
    }

    private var buildNumber: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "?"
    }

    var body: some View {
        List {

            Section {
                HStack(alignment: .center, spacing: 14) {
                    AppIconView(size: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(appName)
                            .font(.headline)

                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Credits") {
                Text("Crafted by Christian Ruppelt")
            }

            Section("Thanks") {
                Text("Lilly C.")
                Text("Tim K.")
                Text("Claudia W.")
            }

            Section("Purpose") {
                Text("A fast place to collect screenshots and inspiration. Built for focus and clarity. TrendVault Mobile is part of the Leuchtturm Marketer Suite.")
                    .foregroundStyle(.secondary)
            }

            Section("Links") {
                Link("Support", destination: URL(string: "https://www.leuchtturm.app")!)
                Link("Privacy Policy", destination: URL(string: "https://www.leuchtturm.app/privacy.html")!)
            }
        }
        .navigationTitle("About")
    }
}

private struct AppIconView: View {

    let size: CGFloat

    var body: some View {
        if let uiImage = loadIcon() {
            Image(uiImage: uiImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .strokeBorder(.secondary.opacity(0.18), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(.thinMaterial)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "app")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                )
        }
    }

    private func loadIcon() -> UIImage? {
        // Best effort. Works for App Store icon setup. Falls back if unavailable.
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let last = files.last {
            return UIImage(named: last)
        }

        if let iconName = Bundle.main.infoDictionary?["CFBundleIconName"] as? String {
            return UIImage(named: iconName)
        }

        return nil
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
