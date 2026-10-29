import CoreGraphics
import CoreText
import Foundation
import PRPetsArt
import PRPetsCore

/// Draws a `YardScene` into a top-left-origin CGContext. Used by the app's overlay and the preview tool alike.
public struct YardRenderer {
    private let sprites: SpriteCache

    public init(sprites: SpriteCache) {
        self.sprites = sprites
    }

    public func draw(_ scene: YardScene, in context: CGContext) {
        context.saveGState()
        context.interpolationQuality = .none
        let placements = scene.placements(using: sprites)
        let behindDoghouse = placements.filter { $0.pet.position.depth < YardViewport.doghouseDepth }
        let inFrontOfDoghouse = placements.filter { $0.pet.position.depth >= YardViewport.doghouseDepth }

        // Labels of pets behind the doghouse go behind it too, so it never wears someone else's name.
        drawLayer(behindDoghouse, scene: scene, in: context)
        drawDoghouse(scene, in: context)
        drawLayer(inFrontOfDoghouse, scene: scene, in: context)
        drawBadge(scene, in: context)
        if let card = scene.hoverCard, let placement = placements.first(where: { $0.pet.id == card.petID }) {
            drawHoverCard(card, above: placement, scene: scene, in: context)
        }
        context.restoreGState()
    }

    private func drawLayer(_ placements: [PetPlacement], scene: YardScene, in context: CGContext) {
        placements.forEach { drawPet($0, in: context) }
        placements.forEach { drawSleepyZs(over: $0, scene: scene, in: context) }
        placements.forEach { drawLabel(for: $0, scene: scene, in: context) }
    }

    // MARK: Sprites

    private func drawPet(_ placement: PetPlacement, in context: CGContext) {
        guard placement.opacity > 0 else { return }
        context.saveGState()
        context.setAlpha(placement.opacity)
        drawUpright(placement.frame.image, in: placement.spriteRect, context: context)
        context.restoreGState()
    }

    private func drawDoghouse(_ scene: YardScene, in context: CGContext) {
        let rect = scene.viewport.doghouseRect
        drawUpright(sprites.doghouse, in: rect, context: context)
        let someoneIsHome = scene.doghouse.petsAreInside && scene.doghouse.waitingCount > 0
        if someoneIsHome { drawPeekingEyes(in: rect, scale: scene.viewport.scale, context: context) }
    }

    /// Two glinting eyes in the doorway when pets are tucked inside.
    private func drawPeekingEyes(in doghouseRect: CGRect, scale: CGFloat, context: CGContext) {
        let doorCentreX = doghouseRect.minX + CGFloat(DoghouseArt.doorCentreX) * scale
        let eyeY = doghouseRect.maxY - CGFloat(DoghouseArt.doorHeight - 4) * scale
        context.setFillColor(CGColor(srgbRed: 1, green: 0.85, blue: 0.35, alpha: 1))
        for offset in [-2.0, 1.0] {
            context.fill(CGRect(x: doorCentreX + CGFloat(offset) * scale, y: eyeY, width: scale, height: scale))
        }
    }

    /// CGContext.draw assumes a bottom-left origin; flip locally so images stay upright in a top-left context.
    private func drawUpright(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: 0, y: rect.minY + rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: rect)
        context.restoreGState()
    }

    // MARK: Overlays

    private func drawLabel(for placement: PetPlacement, scene: YardScene, in context: CGContext) {
        guard let label = placement.pet.entry.label, placement.opacity > 0.2 else { return }
        let text = [label, placement.pet.entry.stackPosition?.description].compactMap { $0 }.joined(separator: " · ")
        let fontSize = Self.labelFontSize(for: scene.viewport.scale)
        let line = TextLine(text, size: fontSize, weight: .semibold, colour: Palette.labelText)
        let padding = CGSize(width: fontSize * 0.5, height: fontSize * 0.2)
        let size = CGSize(width: line.width + padding.width * 2, height: fontSize + padding.height * 2)
        let rect = CGRect(
            x: placement.bodyRect.midX - size.width / 2,
            y: placement.bodyRect.minY - size.height - 2,
            width: size.width, height: size.height
        )
        context.saveGState()
        context.setAlpha(placement.opacity)
        fillRoundedRect(rect, radius: size.height / 2, colour: Palette.labelBackground, in: context)
        line.draw(at: CGPoint(x: rect.minX + padding.width, y: rect.maxY - padding.height - fontSize * 0.22), in: context)
        context.restoreGState()
    }

    private func drawSleepyZs(over placement: PetPlacement, scene: YardScene, in context: CGContext) {
        guard placement.pet.isAsleep else { return }
        let scale = scene.viewport.scale
        let phase = scene.yard.clock.truncatingRemainder(dividingBy: 2.4) / 2.4
        let fontSize = max(8, scale * 3)
        let origin = CGPoint(
            x: placement.bodyRect.maxX - scale * 2 + CGFloat(phase) * scale * 3,
            y: placement.bodyRect.minY - CGFloat(phase) * scale * 6
        )
        context.saveGState()
        context.setAlpha(CGFloat(1 - phase))
        TextLine("z", size: fontSize, weight: .bold, colour: Palette.sleepyZ).draw(at: origin, in: context)
        context.restoreGState()
    }

    private func drawBadge(_ scene: YardScene, in context: CGContext) {
        let status = scene.doghouse
        let doghouseRect = scene.viewport.doghouseRect
        let scale = scene.viewport.scale
        let diameter = max(14, scale * 6)
        let centre = CGPoint(x: doghouseRect.maxX - scale * 6, y: doghouseRect.minY + scale * 6)
        let badge: (text: String, fill: CGColor)? =
            if status.hasProblem { ("!", Palette.problemBadge) }
            else if status.waitingCount > 0 { ("\(status.waitingCount)", Palette.countBadge) }
            else { nil }
        guard let badge else { return }
        let line = TextLine(badge.text, size: diameter * 0.62, weight: .bold, colour: Palette.badgeText)
        let width = max(diameter, line.width + diameter * 0.5)
        let rect = CGRect(x: centre.x - width / 2, y: centre.y - diameter / 2, width: width, height: diameter)
        fillRoundedRect(rect, radius: diameter / 2, colour: Palette.badgeOutline, in: context)
        fillRoundedRect(rect.insetBy(dx: 1.5, dy: 1.5), radius: diameter / 2 - 1.5, colour: badge.fill, in: context)
        line.draw(at: CGPoint(x: rect.midX - line.width / 2, y: rect.maxY - diameter * 0.3), in: context)
    }

    private func drawHoverCard(_ card: HoverCard, above placement: PetPlacement, scene: YardScene, in context: CGContext) {
        let fontSize: CGFloat = 12
        let title = TextLine(Self.truncated(card.title, to: 46), size: fontSize, weight: .semibold, colour: Palette.cardText)
        let reference = TextLine(card.reference + "  ", size: fontSize - 1, weight: .regular, colour: Palette.cardSubtle)
        let additions = TextLine("+\(card.lineDelta.additions) ", size: fontSize - 1, weight: .semibold, colour: Palette.additions)
        let deletions = TextLine("−\(card.lineDelta.deletions)", size: fontSize - 1, weight: .semibold, colour: Palette.deletions)
        let padding: CGFloat = 8
        let secondLineWidth = reference.width + additions.width + deletions.width
        let size = CGSize(width: max(title.width, secondLineWidth) + padding * 2, height: fontSize * 2 + padding * 2 + 4)
        let labelClearance: CGFloat = placement.pet.entry.label == nil ? 4 : Self.labelFontSize(for: scene.viewport.scale) + 10
        let unclampedX = placement.bodyRect.midX - size.width / 2
        let rect = CGRect(
            x: min(max(4, unclampedX), scene.viewport.viewSize.width - size.width - 4),
            y: max(4, placement.bodyRect.minY - labelClearance - size.height - 4),
            width: size.width, height: size.height
        )
        fillRoundedRect(rect.offsetBy(dx: 0, dy: 2), radius: 8, colour: Palette.cardShadow, in: context)
        fillRoundedRect(rect, radius: 8, colour: Palette.cardBackground, in: context)
        let firstBaseline = rect.minY + padding + fontSize * 0.85
        title.draw(at: CGPoint(x: rect.minX + padding, y: firstBaseline), in: context)
        let secondBaseline = firstBaseline + fontSize + 5
        var x = rect.minX + padding
        for part in [reference, additions, deletions] {
            part.draw(at: CGPoint(x: x, y: secondBaseline), in: context)
            x += part.width
        }
    }

    private func fillRoundedRect(_ rect: CGRect, radius: CGFloat, colour: CGColor, in context: CGContext) {
        context.setFillColor(colour)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: min(radius, rect.width / 2), cornerHeight: min(radius, rect.height / 2), transform: nil))
        context.fillPath()
    }

    static func labelFontSize(for scale: CGFloat) -> CGFloat {
        min(13, max(9, scale * 3.2))
    }

    private static func truncated(_ text: String, to length: Int) -> String {
        text.count <= length ? text : String(text.prefix(length - 1)) + "…"
    }
}

enum Palette {
    static let labelBackground = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.88)
    static let labelText = CGColor(srgbRed: 0.16, green: 0.12, blue: 0.2, alpha: 1)
    static let sleepyZ = CGColor(srgbRed: 0.45, green: 0.55, blue: 0.85, alpha: 1)
    static let countBadge = CGColor(srgbRed: 0.18, green: 0.49, blue: 0.88, alpha: 1)
    static let problemBadge = CGColor(srgbRed: 0.96, green: 0.68, blue: 0.13, alpha: 1)
    static let badgeOutline = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    static let badgeText = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    static let cardBackground = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.97)
    static let cardShadow = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.18)
    static let cardText = CGColor(srgbRed: 0.12, green: 0.12, blue: 0.16, alpha: 1)
    static let cardSubtle = CGColor(srgbRed: 0.42, green: 0.42, blue: 0.48, alpha: 1)
    static let additions = CGColor(srgbRed: 0.1, green: 0.6, blue: 0.25, alpha: 1)
    static let deletions = CGColor(srgbRed: 0.82, green: 0.2, blue: 0.2, alpha: 1)
}

/// A single line of text, measured once and drawable into a top-left-origin context at a baseline.
struct TextLine {
    enum Weight { case regular, semibold, bold }

    private let line: CTLine
    let width: CGFloat

    init(_ text: String, size: CGFloat, weight: Weight, colour: CGColor) {
        let fontName = switch weight {
        case .regular: "HelveticaNeue"
        case .semibold: "HelveticaNeue-Medium"
        case .bold: "HelveticaNeue-Bold"
        }
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName(fontName as CFString, size, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): colour,
        ]
        line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    func draw(at baseline: CGPoint, in context: CGContext) {
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = baseline
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
