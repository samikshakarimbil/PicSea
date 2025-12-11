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



