# PicSea

## Sam & Sydney's Senior Project


Project File Structure:

PicSea/
│
|-- PicSeaApp.swift                     # App entry point
|-- ContentView.swift                   # Root view or main tab view
|-- PicSea.entitlements                 # ??
|-- Assets.xcassets                     # ?
│
|-- Views/                              # All SwiftUI screens
│
|-- ViewModels/                         # ObservableObjects (logic + state)
│   |-- PhotoLibraryViewModel.swift     # Handles fetching/managing photos
│
|-- Models/                             # Data structures
│
|-- Services/                           # Non-UI utilities (Core ML, Photos, etc.)
│   |-- PhotoLibraryManager.swift       # PhotoKit interactions
│  


PicSeaTests/
|
|-- PicSeaTests.swift

PicSeaUITests/
|
|-- PicSeaUITests.swift
|-- PicSeaUITestsLaunchTests.swift



