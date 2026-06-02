//
//  PicSeaApp.swift
//  PicSea
//

import SwiftUI
import SwiftData

@main
struct PicSeaApp: App {
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: PhotoIndexRecord.self)
        } catch {
            fatalError("Failed to create photo index container: \(error)")
        }
    }()

    private let classifier: ClassifierProtocol = {
        let vision = VisionClassifier()
        if vision.isAvailable {
            print("Using VisionClassifier")
            return vision
        } else {
            print("Vision unavailable -> Using LocalMLClassifier")
            return LocalMLClassifier()
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(vm: PhotoLibraryViewModel(
                classifier: classifier,
                modelContext: modelContainer.mainContext
            ))
        }
        .modelContainer(modelContainer)
    }
}
