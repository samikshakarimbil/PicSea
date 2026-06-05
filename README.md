# PicSea
## Sydney Lynch & Samiksha Karimbil

PicSea is an iOS app for searching a user's photo library with natural-language prompts, applying structured filters, and saving selected results into albums.

## Overview

The app combines prompt parsing, photo-library access, and image classification to help users narrow large photo collections quickly. Users can start with a plain-English search, refine the results with filters, and optionally save the final set to a new or existing album.

## Features

- Natural-language photo search
- Structured filtering by media type, date range, and blur preference
- Photo library browsing with thumbnail grids
- Multi-step search sessions with editable filters
- Selection mode for saving chosen results
- Album creation and result export inside Photos
- Vision-based classification with a local fallback path

## Screenshots

Add screenshots here:
- Main library view
- Search session with filters open
- Selected results ready to save
- Album creation flow

## Requirements

iOS 16.0 or later
iPhone or iPad
Photos permission granted at runtime
Xcode 15 or later for building and running the project locally

## Getting Started

1. Open `PicSea.xcodeproj` in Xcode.
2. Select a run destination (physical device using iOS 16+)
3. Build and run the app.
4. Grant Photos access when prompted.
5. Enter a search prompt such as `blurry selfies` or `dog pictures`.

## How It Works

1. The user enters a prompt in the main library view.
2. `PromptParser` converts the prompt into a `PhotoSearchQuery`.
3. `SearchSessionView` presents editable filters and the matching assets.
4. `PhotoLibraryViewModel` fetches photo assets, applies filters, and coordinates classification.
5. Matching photos can be selected and saved into a Photos album.

## Project Structure

```text
PicSea/
├── PicSea.xcodeproj
├── README.md
├── PicSea/
│   ├── Assets.xcassets
│   ├── ContentView.swift
│   ├── Info.plist
│   ├── Models/
│   ├── Services/
│   ├── ViewModels/
│   ├── Views/
│   └── PicSeaApp.swift
├── PicSeaTests/
└── PicSeaUITests/
```

### Key Modules

- `Models/PhotoSearchQuery.swift` defines the search query model and media-type filters.
- `Services/PhotoLibraryManager.swift` contains Photos-related helper logic.
- `Services/PromptParser.swift` translates user prompts into structured queries.
- `Services/ClassifierProtocol.swift` defines the classification interface.
- `Services/VisionClassifier.swift` handles Vision-based classification when available.
- `Services/LocalMLClassifier.swift` provides a local fallback classifier implementation.
- `ViewModels/PhotoLibraryViewModel.swift` owns photo fetching, filtering, and album saving.
- `Views/SearchSessionView.swift` presents the filtered search experience.
- `Views/AlbumCreationView.swift` handles album naming and creation.

## Permissions

PicSea requires access to the user’s photo library in order to browse assets, run searches, and save results to albums. The app requests Photos permission at runtime and updates the interface based on the authorization state.

## Testing

The repository includes both unit test and UI test targets:
- `PicSeaTests` - Unit tests for models, services and view models
- `PicSeaUITests` - End-to-end UI interaction tests
Run them from Xcode using the active scheme’s test action.

## Notes

- The classifier layer is abstracted behind `ClassiferProtocol`, making it straightforward to swap in new implementations (e.g., a Core ML model or a remote API) without touching the rest of the pipeline.
- Search behavior intentionally combines prompt parsing with structured filters rather than relying on a single free-form query, which improves result precision on ambiguous input.

Academic project — not licensed for reuse
