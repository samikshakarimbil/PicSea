//
//  PicSeaApp.swift
//  PicSea
//

import SwiftUI

@main
struct PicSeaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
//
//
//import Vision
//
//// struct to hold image url and output classifiers
//struct ImageFile {
//    var url: URL
//    var observations: [String: VNConfidence] = [:]
//}
//
//// function that takes in an image url and calls the Apple classifier API
//func classifyImage(url: URL) async throws -> ImageFile {
//    var image = ImageFile(url: url)
//    let request = ClassifyImageRequest()
//
//    let results = try await request.perform(on: url)          // THE api call
//        .filter { $0.hasMinimumPrecision(0.1, forRecall: 0.8) }
//
//    // add each result to the output struct
//    for classification in results {
//        image.observations[classification.identifier] = classification.confidence
//    }
//    
//    return image
//}
//
//@main
//struct ClassificationTestApp {
//    static func main() async {
//        do {
//            // get the image of bobby from the project folder
//            guard let url = Bundle.main.url(forResource: "bobby", withExtension: "png") else {
//                print("Image not found in app bundle.")
//                return
//            }
//            // run the classifier
//            let result = try await classifyImage(url: url)
//            print("Classification succeeded:")
//            print(result.observations)
//        } catch {
//            print("Classification failed:", error)
//        }
//    }
//}
