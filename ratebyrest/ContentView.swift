import Foundation
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    @State private var tab = Self.initialTab

    private static var initialTab: Int {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--globe") { return 1 }
        #endif
        return 0
    }

    var body: some View {
        TabView(selection: $tab) {
            ExploreView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            GlobeView()
                .tabItem { Label("Globe", systemImage: "globe.europe.africa") }
                .tag(1)
            NavigationStack {
                AccountView()
            }
            .tabItem { Label("Account", systemImage: "person.crop.circle") }
            .tag(2)
        }
        .tint(Theme.accent)
        .preferredColorScheme(.light)
        .task {
            await model.refreshSession()
            await model.refreshSchema()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
