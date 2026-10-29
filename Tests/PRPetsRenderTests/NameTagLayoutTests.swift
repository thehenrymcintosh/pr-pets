import CoreGraphics
import PRPetsCore
import PRPetsRender
import Testing

private func request(_ id: String, x: CGFloat, width: CGFloat = 80) -> NameTagLayout.Request {
    NameTagLayout.Request(id: PullRequestID(id), size: CGSize(width: width, height: 16), anchor: CGPoint(x: x, y: 200))
}

@Suite("Name tag layout")
struct NameTagLayoutTests {
    @Test func tagsThatFitStayRightAbovetheirPets() {
        let frames = NameTagLayout.arrange([request("a", x: 100), request("b", x: 300)], withinWidth: 800)
        #expect(frames[PullRequestID("a")]?.maxY == 198)
        #expect(frames[PullRequestID("b")]?.maxY == 198)
    }

    @Test func crowdedTagsStepUpInsteadOfOverlapping() {
        // Neighbours 40pt apart overlap, so every other tag steps up a row.
        let crowd = (0..<6).map { request("pet\($0)", x: 200 + CGFloat($0) * 40) }
        let frames = Array(NameTagLayout.arrange(crowd, withinWidth: 800).values)
        for (index, frame) in frames.enumerated() {
            for other in frames[(index + 1)...] { #expect(!frame.intersects(other)) }
        }
        #expect(frames.count == crowd.count)
    }

    @Test func aPileOfPetsShowsAsManyTagsAsThereAreRows() {
        let pile = (0..<6).map { request("pet\($0)", x: 200) }
        #expect(NameTagLayout.arrange(pile, withinWidth: 800).count == NameTagLayout.maximumRows)
    }

    @Test func higherPriorityTagsKeepTheBottomRow() {
        let frames = NameTagLayout.arrange([request("hovered", x: 210), request("other", x: 200)], withinWidth: 800)
        #expect(frames[PullRequestID("hovered")]!.maxY > frames[PullRequestID("other")]!.maxY)
    }

    @Test func tagsKeepOffTheBadge() {
        let badge = CGRect(x: 60, y: 180, width: 20, height: 20)
        let frame = NameTagLayout.arrange([request("a", x: 100)], withinWidth: 800, avoiding: [badge])[PullRequestID("a")]
        #expect(frame.map { !$0.intersects(badge) } == true)
    }

    @Test func tagsStayOnScreen() {
        let frames = NameTagLayout.arrange([request("edge", x: 5), request("far", x: 795)], withinWidth: 800)
        #expect(frames.values.allSatisfy { $0.minX >= 0 && $0.maxX <= 800 })
    }
}
