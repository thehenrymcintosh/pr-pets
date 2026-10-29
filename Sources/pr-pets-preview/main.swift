import Foundation
import PRPetsCore

let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first ?? "all"
let outputDirectory = URL(fileURLWithPath: arguments.count > 1 ? arguments[arguments.count - 1] : "previews")

func writeSheets() throws {
    try ImageWriter.writePNG(ContactSheet.render(seedCount: 60, pose: .stand, scale: 6), to: outputDirectory.appending(path: "pets.png"))
    try ImageWriter.writePNG(ContactSheet.renderPoses(seedCount: 8, scale: 6), to: outputDirectory.appending(path: "poses.png"))
    for species in Species.allCases {
        let image = ContactSheet.render(seedCount: 20, pose: .stand, scale: 8, species: [species])
        try ImageWriter.writePNG(image, to: outputDirectory.appending(path: "species-\(species.rawValue).png"))
    }
}

func writeScenario(_ scenario: Scenario) throws {
    let frames = ScenarioRecorder(scenario: scenario).record()
    let delay = ScenarioRecorder.simulationStep * Double(ScenarioRecorder.framesPerCapture)
    try ImageWriter.writeGIF(frames, to: outputDirectory.appending(path: "scenario-\(scenario.name).gif"), frameDelay: delay)
    try ImageWriter.writePNG(Filmstrip.make(from: frames, count: 5), to: outputDirectory.appending(path: "scenario-\(scenario.name)-strip.png"))
    print("  \(scenario.name): \(frames.count) frames")
}

do {
    switch command {
    case "sheet", "species", "poses":
        try writeSheets()
    case "scenario":
        let name = arguments.count > 2 ? arguments[1] : ""
        guard let scenario = Scenario.all.first(where: { $0.name == name }) else {
            throw PreviewError.unknownCommand("scenario \(name) (have: \(Scenario.all.map(\.name).joined(separator: ", ")))")
        }
        try writeScenario(scenario)
    case "icon":
        try AppIcon.writeIconset(to: outputDirectory)
    case "scenarios":
        try Scenario.all.forEach(writeScenario)
    case "all":
        try writeSheets()
        try Scenario.all.forEach(writeScenario)
    default:
        throw PreviewError.unknownCommand(command)
    }
    print("Wrote previews to \(outputDirectory.path)")
} catch {
    FileHandle.standardError.write(Data("pr-pets-preview: \(error)\n".utf8))
    exit(1)
}
