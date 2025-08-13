import SwiftUI

@main
struct MyApp: App {
    @StateObject private var userManager = UserManager.shared
    @StateObject private var interestsManager = InterestsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userManager)
                .environmentObject(interestsManager)
        }
    }
}
