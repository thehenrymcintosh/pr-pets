// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "pr-pets",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PRPets", targets: ["PRPetsApp"]),
        .executable(name: "pr-pets-preview", targets: ["pr-pets-preview"]),
    ],
    targets: [
        // Pure domain: pull requests, review queue, triage, pet genomes and the yard simulation.
        .target(name: "PRPetsCore"),
        // Procedural pixel art: genome -> sprite frames. CoreGraphics-free raw RGBA.
        .target(name: "PRPetsArt", dependencies: ["PRPetsCore"]),
        // Scene layout + CoreGraphics drawing shared by the app and the headless preview tool.
        .target(name: "PRPetsRender", dependencies: ["PRPetsCore", "PRPetsArt"]),
        // PullRequestSource backed by the local `gh` CLI.
        .target(name: "PRPetsGitHub", dependencies: ["PRPetsCore"]),
        // Checks GitHub Releases for a newer version and installs it in place.
        .target(name: "PRPetsUpdates"),
        // Scripted PullRequestSource used by demo mode, the preview tool and tests.
        .target(name: "PRPetsDemo", dependencies: ["PRPetsCore"]),
        .executableTarget(
            name: "PRPetsApp",
            dependencies: ["PRPetsCore", "PRPetsArt", "PRPetsRender", "PRPetsGitHub", "PRPetsDemo", "PRPetsUpdates"]
        ),
        .executableTarget(
            name: "pr-pets-preview",
            dependencies: ["PRPetsCore", "PRPetsArt", "PRPetsRender", "PRPetsDemo"]
        ),
        .testTarget(name: "PRPetsCoreTests", dependencies: ["PRPetsCore", "PRPetsDemo"]),
        .testTarget(name: "PRPetsArtTests", dependencies: ["PRPetsCore", "PRPetsArt"]),
        .testTarget(name: "PRPetsUpdatesTests", dependencies: ["PRPetsUpdates"]),
        .testTarget(name: "PRPetsRenderTests", dependencies: ["PRPetsCore", "PRPetsRender", "PRPetsDemo"]),
        .testTarget(
            name: "PRPetsGitHubTests",
            dependencies: ["PRPetsCore", "PRPetsGitHub"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
