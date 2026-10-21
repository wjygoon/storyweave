// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StoryWeaveAI",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "StoryWeaveAI",
            targets: ["StoryWeaveAI"]
        )
    ],
    targets: [
        .target(
            name: "StoryWeaveAI",
            path: "StoryWeaveAI"
        )
    ]
)

// MARK: - Dependencies Note
/*
  StoryWeaveAI uses NO third-party dependencies.
  All features are implemented using Apple's native frameworks:
  - SwiftUI for UI
  - SwiftData for local persistence
  - StoreKit 2 for subscriptions
  - AuthenticationServices for Sign in with Apple
  - URLSession for network requests (Gemini, DALL-E, Supabase)
  
  If you later want to add the official Supabase Swift SDK:
  Add this under dependencies:
    .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
  
  And add the target dependency:
    .product(name: "Supabase", package: "supabase-swift")
*/
