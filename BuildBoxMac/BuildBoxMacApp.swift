import SwiftUI

@main
struct BuildBoxMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 750)
                .frame(width: 620, height: 780)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }
}
