//
//  PicSeaApp.swift
//  PicSea
//
//  Created by Sydney Lynch on 10/9/25.
//

import Vision
struct ImageFile {
  var url: URL
  var observations: [String: VNConfidence] = [:]
}

func classifyImage(url: URL) async throws -> ImageFile {
  var image = ImageFile(url: url)
  let request = ClassifyImageRequest()

  let results = try await request.perform(on: url)
    .filter { $0.hasMinimumPrecision(0.1, forRecall: 0.8) }
  for classification in results {
    image.observations[classification.identifier] = classification.confidence
  }
  return image
}

@main
struct ClassificationTestApp {
    static func main() async {
        do {
            guard let url = Bundle.main.url(forResource: "bobby", withExtension: "png") else {
                print("Image not found in app bundle.")
                return
            }
            let file = try await classifyImage(url: url)
            print("Classification succeeded:")
            print(file)
        } catch {
            print("Classification failed:", error)
        }
    }
}
