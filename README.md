# PicSea

## Sydney Lynch & Samiksha Karimbil

PicSea is an iOS application that helps users quickly locate photos within large personal photo libraries using natural-language search. The project combines prompt parsing, image classification, and structured filtering to bridge the gap between traditional photo browsing and AI-assisted image retrieval. All of this is done locally on the device, with no need for third-party cloud services, creating a secure option for photo navigation.

## Overview

The app combines prompt parsing, photo-library access, and image classification to help users narrow large photo collections quickly. Users can start with a plain-English search, refine the results with filters, and optionally save the final set to a new or existing album.

## Features

- Natural-language photo search prompt
- Structured filtering by media type, date range, duplication factor, and blur preference
- Photo library browsing with thumbnail grids
- Multi-step search sessions with editable filters
- Selection mode for saving chosen results
- Album creation and result export linked to Apple Photos
- Vision-based classification with a local fallback path

## Screenshots

### Main Page

<img src="PicSea/images/main_page.png" height=500>
<img src="PicSea/images/main_settings.png" height=500>

### Results Filtering

<img src="PicSea/images/results.png" height=500>
<img src="PicSea/images/results_filters.png" height=500>

### Album Creation

<img src="PicSea/images/result_selection.png" height=500>
<img src="PicSea/images/create_album.png" height=500>

## Requirements

iOS 16.0 or later (iPhone or iPad)  
Xcode 15 or later for building and running the project locally  
Photos permission granted at runtime

## Getting Started

1. Open `PicSea.xcodeproj` in Xcode.
2. Plug your physical iOS device into your Mac and select it as the run destination at the top of Xcode.
3. Link your Apple Account to the project using the signing steps below.
4. **On your iOS device:** Ensure Developer Mode is on (Go to **Settings > Privacy & Security > Developer Mode** and toggle it ON. Restart your device if prompted).
5. Build and run the app (**Product > Run** or `⌘R`).
   - _Note:_ If you get an "Untrusted Developer" popup on your phone, go to **Settings > General > VPN & Device Management**, tap your Apple ID, and choose **Trust**.
6. Grant Photos access when prompted by the app.
7. Enter a search prompt such as `blurry selfies` or `dog pictures` and begin filtering!

### How to Link Your Apple Account to the Project

1. Open the project file (`.xcodeproj`) in Xcode.
2. Open the **Project Navigator** sidebar on the far left.
3. Click on the blue **root project node** (the very top item in the file tree).
4. Ensure that **PicSea** is selected under the **Targets** section in the inner sidebar.
5. Open the **Signing & Capabilities** tab at the top.
6. Ensure that **Automatically manage signing** is checked.
7. In the **Team** dropdown, select your Apple account. If none are listed, select **Add an account...** and sign in with your Apple ID and password.

## How It Works

1. The user enters a prompt in the main library view.
2. `PromptParser` converts the prompt into a `PhotoSearchQuery`.
3. `SearchSessionView` presents editable filters and the matching assets.
4. `PhotoLibraryViewModel` fetches photo assets, applies filters, and coordinates classification.
5. Classification results are indexed and cached to improve performance during future searches.
6. Desired photos can be selected and saved into a Photos album.

## Design Decisions

PicSea was designed around a hybrid search pipeline that combines natural-language prompts with structured filtering. Rather than relying solely on image classification, user prompts are first translated into a structured `PhotoSearchQuery`, allowing search criteria such as media type, date ranges, duplication level, and blur preference to be applied consistently and efficiently.

To keep the interface responsive on large photo libraries, the app uses an indexing and caching strategy. Classification results are cached after processing so that assets do not need to be repeatedly analyzed during subsequent searches. This significantly reduces search latency and prevents the application from becoming unresponsive when working with thousands of photos.

The classification layer is abstracted behind `ClassifierProtocol`, allowing different classification implementations to be substituted without modifying the rest of the application. This design makes it possible to replace the current Vision-based implementation with future Core ML models or remote inference services.

## Project Key Components

- `Models/PhotoSearchQuery.swift` defines the search query model and media-type filters.
- `Services/PhotoLibraryManager.swift` contains Photos-related helper logic.
- `Services/PromptParser.swift` translates user prompts into structured queries.
- `Services/ClassifierProtocol.swift` defines the classification interface.
- `Services/VisionClassifier.swift` handles Vision-based classification when available.
- `Services/LocalMLClassifier.swift` provides a local fallback classifier implementation.
- `ViewModels/PhotoLibraryViewModel.swift` owns photo fetching, filtering, and album saving.
- `Views/SearchSessionView.swift` presents the filtered search experience.
- `Views/AlbumCreationView.swift` handles album naming and creation.

## Technical Challenges

### Large Photo Libraries

One of the primary challenges was maintaining performance when processing large photo collections. Running image classification on every asset can be computationally expensive and may cause long delays before results appear. To address this, PicSea uses cached classification results and indexed metadata to avoid repeatedly processing the same images.

### Device Hardware Requirements

PicSea relies on Apple's Vision framework for image classification. Since image analysis is computationally intensive, search performance depends on the processing capabilities of the device. Newer iPhones can classify and index large photo libraries significantly faster than older hardware.

### Simulator Limitations

Development and testing of the classification pipeline could not be fully performed within the iOS Simulator. The simulator lacks access to the same hardware-accelerated Vision processing available on physical devices, requiring most classification testing and validation to be conducted directly on iPhones.

## Results

PicSea successfully supports natural-language photo retrieval across a user's local photo library while maintaining an interactive search experience. By combining prompt parsing, structured filters, and cached classification results, the application is able to narrow large collections into manageable result sets without relying on external cloud services.

## Limitations and Future Work

The original project vision included training and deploying a custom machine learning model tailored specifically to photo-library search. Due to project time constraints, the final implementation relies primarily on Apple's Vision framework rather than a fully custom model.

Future work could include:

- Training a dedicated Core ML model optimized for personal photo retrieval.
- Expanding prompt understanding beyond the current query structure.
- Supporting semantic ranking of results instead of filter-based retrieval alone.
- Adding background indexing to further reduce search latency on large libraries.
- Improving duplicate-photo detection and similarity scoring.
- Providing on-device personalization based on user search history.
