//
//  PicSeaApp.swift
//  PicSea
//

import SwiftUI

@main
struct PicSeaApp: App {
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
            ContentView(vm: PhotoLibraryViewModel(classifier: classifier))
        }
    }
}
