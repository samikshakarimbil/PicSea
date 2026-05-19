# PicSea

## Sam & Sydney's Senior Project


Project File Structure:

PicSea/  
│  
|-- PicSeaApp.swift                     # App entry point  
|-- ContentView.swift                   # Root view or main tab view  
|-- PicSea.entitlements                 # ??  
|-- Assets.xcassets                     # ?  
|-- README.md                           # this file
|-- Info.plist
│  
|-- Views/                              # All SwiftUI screens  
│   |-- AlbumCreationView.swift         # ?
│  
|-- ViewModels/                         # ObservableObjects (logic + state)  
│   |-- PhotoLibraryViewModel.swift     # Handles fetching/managing photos 
|   |-- AssetThumbnail.swift            # ? 
│  
|-- Models/                             # Data structures  
│  
|-- Services/                           # Non-UI utilities (Core ML, Photos, etc.)  
│   |-- PhotoLibraryManager.swift       # PhotoKit interactions  
│   |-- VisionClassifier.swift          # Apple ML vision stuff
│   |-- LocalMLClassifier.swift         # fallback AI when Apple Vision unavailable
│   |-- ClassifierProtocol.swift        # parent AI protocol


PicSeaTests/  
|  
|-- PicSeaTests.swift  

PicSeaUITests/  
|  
|-- PicSeaUITests.swift  
|-- PicSeaUITestsLaunchTests.swift  

# AI Camera Roll Assistant

## Sydney Lynch & Samiksha Karimbil

An iOS application that reimagines photo library navigation using on-device AI, semantic search, duplicate detection, and intelligent photo indexing.

Built as a senior project using SwiftUI, PhotoKit, Vision, and a persistent local indexing pipeline designed to scale to large camera rolls without excessive memory usage.

---

# Overview

Modern camera rolls contain thousands of photos, screenshots, duplicates, and forgotten memories that become difficult to navigate over time.

This project explores a new interaction model for photo libraries:

> Instead of scrolling endlessly, users can ask for what they want.

Examples:
- “Beach photos with friends”
- “Blurry photos from last month”
- “Duplicate screenshots”
- “Pictures of my dog”
- “Selfies from 2024”

The application combines:
- semantic search
- duplicate grouping
- blur analysis
- metadata indexing
- lightweight caching
- lazy thumbnail loading

to provide a responsive, memory-efficient browsing experience on-device.

---

# Features

## Intelligent Search
Search the photo library using natural language prompts and metadata filters.

## Duplicate Detection
Detect visually similar photos using:
- perceptual hashing
- nearby-window comparisons
- optional Vision feature-print refinement

## Blur Detection
Identify blurry or low-quality photos using lightweight image analysis.

## Smart Filtering
Filter results by:
- photos
- screenshots
- selfies
- duplicates
- blurry images
- date ranges

## Persistent Local Index
The app maintains a lightweight on-device photo index for fast searches and scalable performance.

## Lazy Thumbnail Loading
Only visible thumbnails are loaded into memory to avoid crashes and excessive RAM usage.

## Background Indexing Pipeline
Photo analysis occurs incrementally in small batches while the app is idle.

---

# Architecture

The application is designed around a lightweight local indexing system.

```text
Photo Library (PhotoKit)
        ↓
Local Persistent Index
        ↓
Search + Filtering + AI Analysis
        ↓
Visible Thumbnail Rendering
```

The core principle is:

> Store metadata and asset identifiers, not full-resolution images.

This allows the application to scale to very large photo libraries efficiently.

---

# Core Technologies

- SwiftUI
- SwiftData
- PhotoKit
- Vision Framework
- Core Image
- iOS Background Processing
- LazyVGrid
- Async image loading

---

# Data Model

Each photo in the user’s library corresponds to one persistent index record.

Example fields:

```swift
assetLocalIdentifier
creationDate
pixelWidth
pixelHeight
mediaType
mediaSubtype
isScreenshot
isSelfie
blurScore
perceptualHash
duplicateGroupID
duplicateScore
indexingStatus
lastIndexedAt
indexVersion
```

The database stores lightweight metadata only.

Full-resolution images are never persistently loaded into memory during search operations.

---

# Performance Strategy

The application is specifically designed to avoid memory-related crashes common in large photo-processing apps.

Key strategies include:

## Asset-ID Driven UI

Search results return:

```swift
[String]
```

instead of:

```swift
[UIImage]
```

## Lazy Thumbnail Rendering

Thumbnails are only requested for currently visible cells.

## Small Batch Processing

Background analysis runs incrementally in controlled batches.

## Reduced Image Resolution

Analysis tasks operate on small thumbnail-sized images (typically 256×256).

## Local Persistent Cache

Previously analyzed results are reused across app launches.

---

# Duplicate Detection Strategy

The MVP duplicate detection system focuses on nearby photos in camera-roll order.

Example:

```text
For photo N:
compare against photos N-20 through N+20
```

This dramatically reduces computational complexity while still capturing most real-world duplicate scenarios such as:
- burst photos
- repeated screenshots
- multiple takes
- accidental duplicates

Duplicate matching uses:
1. perceptual hashing
2. similarity thresholding
3. optional Vision feature-print refinement

---

# Search Flow

```text
User enters prompt
        ↓
Search engine queries cached metadata/index
        ↓
Matching asset IDs returned
        ↓
UI lazily loads visible thumbnails
```

This architecture enables responsive searches even with very large libraries.

---

# Current Status

Implemented / In Progress:
- SwiftUI photo grid
- persistent indexing architecture
- duplicate analysis pipeline
- blur analysis
- lazy thumbnail loading
- filter system
- search UI
- PhotoKit integration

Planned:
- semantic Vision embeddings
- natural-language AI ranking
- saved smart collections
- background indexing improvements
- configurable duplicate sensitivity
- conversational assistant workflows

---

# Privacy

All photo analysis is designed to occur locally on-device.

The application does not require uploading photos to external servers.

---

# Challenges Explored

This project investigates:
- scalable photo indexing
- on-device AI workflows
- memory-safe image processing
- incremental background analysis
- semantic search UX
- efficient thumbnail rendering
- duplicate detection systems

---

# Future Vision

The long-term goal is to create a true AI-native photo library experience where users interact with memories conversationally instead of navigating static folders and timelines.

---
