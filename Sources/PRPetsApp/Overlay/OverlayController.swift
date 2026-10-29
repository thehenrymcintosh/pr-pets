import AppKit
import Combine
import PRPetsCore
import PRPetsRender
import SwiftUI

/// Runs the yard: keeps it in step with the model, animates it, and handles the mouse.
@MainActor
final class OverlayController: NSObject {
    private let model: AppModel
    private let updates: UpdateController
    private let actions: AppActions
    private let panel = OverlayPanel()
    private let yardView = YardView()
    private var yard: Yard
    private var random = SeededRandom(seed: Seed(UInt64(Date().timeIntervalSince1970)))
    private var layout: OverlayLayout
    private var viewport: YardViewport
    /// The placement while the doghouse is being dragged; committed to preferences on release.
    private var draggingPlacement: DoghousePlacement?
    private var hoveredPetID: PullRequestID?
    private var popover: NSPopover?
    private var popoverPetID: PullRequestID?
    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval?
    private var mouseTracker: Timer?
    private var subscriptions: Set<AnyCancellable> = []

    init(model: AppModel, updates: UpdateController, actions: AppActions) {
        self.model = model
        self.updates = updates
        self.actions = actions
        let preferences = model.effectivePreferences
        layout = OverlayLayout(placement: preferences.placement, scale: preferences.scale)
        viewport = Self.makeViewport(for: layout, preferences: preferences)
        yard = Yard(geometry: viewport.geometry)
        super.init()
    }

    var view: NSView { yardView }

    func show() {
        yardView.delegate = self
        panel.contentView = yardView
        applyLayout()
        panel.orderFrontRegardless()
        startAnimating()
        startTrackingMouse()
        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncWithModel() }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.syncWithModel() }
            .store(in: &subscriptions)
        syncWithModel()
    }

    // MARK: - Model

    private func syncWithModel() {
        let preferences = model.effectivePreferences
        let placement = draggingPlacement ?? preferences.placement
        let newLayout = OverlayLayout(placement: placement, scale: preferences.scale)
        let newViewport = Self.makeViewport(for: newLayout, preferences: preferences)
        if newLayout != layout || newViewport != viewport {
            layout = newLayout
            viewport = newViewport
            applyLayout()
        }
        let roster = model.board?.roster ?? .empty
        yard.reconcile(with: roster)
        yardView.sprites.retainOnly(Set(yard.pets.map(\.genome) + roster.entries.map(\.genome)))
        displayLink?.isPaused = false
        redraw()
    }

    private static func makeViewport(for layout: OverlayLayout, preferences: Preferences) -> YardViewport {
        YardViewport(
            scale: preferences.scale,
            viewSize: layout.panelFrame.size,
            doghouseCentreX: layout.doghouseCentreX,
            roamingArea: preferences.roamingArea,
            roamingWidth: preferences.roamingWidth
        )
    }

    private func applyLayout() {
        panel.setFrame(layout.panelFrame, display: true)
        yardView.frame = CGRect(origin: .zero, size: layout.panelFrame.size)
        yard.relocate(to: viewport.geometry)
    }

    // MARK: - Animation

    private func startAnimating() {
        let link = yardView.displayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        let elapsed = lastFrameTimestamp.map { min(link.timestamp - $0, 0.1) } ?? 0
        lastFrameTimestamp = link.timestamp
        yard.advance(by: elapsed, using: &random)
        redraw()
        // Nothing moves in an empty yard, so stop waking up until something changes.
        if yard.isEmpty {
            link.isPaused = true
            lastFrameTimestamp = nil
        }
    }

    private func redraw() {
        let board = model.board
        let status = DoghouseStatus(
            waitingCount: board?.waitingPetCount ?? 0,
            petsAreInside: model.effectivePreferences.petsAreInside,
            hasProblem: model.syncStatus.problem != nil
        )
        yardView.scene = YardScene(viewport: viewport, yard: yard, doghouse: status, hoverCard: hoverCard())
    }

    private func hoverCard() -> HoverCard? {
        guard model.effectivePreferences.showHoverCards, popover == nil,
              let id = hoveredPetID, let pullRequest = model.snapshot?.pullRequest(withID: id) else { return nil }
        return HoverCard(petID: id, title: pullRequest.title, reference: pullRequest.shortReference, lineDelta: pullRequest.lineDelta)
    }

    // MARK: - Mouse

    /// The panel ignores the mouse except over a pet or the doghouse, so the desktop stays usable underneath.
    private func startTrackingMouse() {
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.trackMouse() }
        }
        RunLoop.main.add(timer, forMode: .common)
        mouseTracker = timer
    }

    private func trackMouse() {
        let windowPoint = panel.convertPoint(fromScreen: NSEvent.mouseLocation)
        let viewPoint = yardView.convert(windowPoint, from: nil)
        let hit = yardView.scene?.hitTest(viewPoint, using: yardView.sprites, keepingHoverOn: hoveredPetID)
        let isInteracting = hit != nil || draggingPlacement != nil
        if panel.ignoresMouseEvents == isInteracting { panel.ignoresMouseEvents = !isInteracting }
        let hoveredPet: PullRequestID? = if case .pet(let id) = hit { id } else { nil }
        updateHover(to: hoveredPet)
    }

    private func updateHover(to petID: PullRequestID?) {
        guard petID != hoveredPetID else { return }
        if let previous = hoveredPetID, previous != popoverPetID { yard.release(previous) }
        if let petID { yard.hold(petID) }
        hoveredPetID = petID
        redraw()
    }

    // MARK: - Pet card

    private func showCard(for petID: PullRequestID) {
        guard let pullRequest = model.snapshot?.pullRequest(withID: petID),
              let placement = yard.pet(withID: petID).map({ yardView.scene?.placement(of: $0, using: yardView.sprites) }) ?? nil
        else { return }
        closeCard()
        yard.hold(petID)
        let card = PetCardView(
            pullRequest: pullRequest,
            stackPosition: model.board?.presence.stackPosition(of: pullRequest),
            onOpen: { [weak self] in self?.model.open(pullRequest); self?.closeCard() },
            onDismiss: { [weak self] in self?.model.dismiss(pullRequest); self?.closeCard() },
            onMute: { [weak self] in self?.model.mute(pullRequest); self?.closeCard() }
        )
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: card)
        popover.delegate = self
        self.popover = popover
        popoverPetID = petID
        NSApp.activate()
        popover.show(relativeTo: placement.bodyRect, of: yardView, preferredEdge: .maxY)
        redraw()
    }

    private func closeCard() {
        popover?.close()
    }
}

extension OverlayController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        if let petID = popoverPetID, petID != hoveredPetID { yard.release(petID) }
        popover = nil
        popoverPetID = nil
        redraw()
    }
}

extension OverlayController: YardViewDelegate {
    func yardView(_ view: YardView, hitAt point: CGPoint) -> SceneHit? {
        view.scene?.hitTest(point, using: view.sprites)
    }

    func yardView(_ view: YardView, clicked hit: SceneHit) {
        switch hit {
        case .doghouse: actions.showDashboard()
        case .pet(let id): showCard(for: id)
        }
    }

    func yardViewDoubleClickedDoghouse(_ view: YardView) {
        model.togglePetsInside()
    }

    func yardView(_ view: YardView, rightClicked hit: SceneHit, with event: NSEvent) {
        let menu = switch hit {
        case .doghouse: doghouseMenu()
        case .pet(let id): petMenu(for: id)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    func yardView(_ view: YardView, draggedDoghouseBy delta: CGSize) {
        let scale = model.effectivePreferences.scale
        let doghouseCentre = CGPoint(
            x: layout.panelFrame.minX + layout.doghouseCentreX + delta.width,
            y: layout.panelFrame.minY + delta.height
        )
        draggingPlacement = OverlayLayout.placement(doghouseCentre: doghouseCentre, panelBottom: doghouseCentre.y, scale: scale)
        syncWithModel()
    }

    func yardViewFinishedDraggingDoghouse(_ view: YardView) {
        guard let placement = draggingPlacement else { return }
        draggingPlacement = nil
        model.updatePreferences { $0.placement = placement }
    }

    private func doghouseMenu() -> NSMenu {
        NSMenu.appMenu(model: model, updates: updates, actions: actions)
    }

    private func petMenu(for id: PullRequestID) -> NSMenu {
        guard let pullRequest = model.snapshot?.pullRequest(withID: id) else { return NSMenu() }
        return NSMenu.build([
            .item("Open \(pullRequest.shortReference)") { [weak self] in self?.model.open(pullRequest) },
            .item("Dismiss Until New Commits") { [weak self] in self?.model.dismiss(pullRequest) },
            .item("Mute") { [weak self] in self?.model.mute(pullRequest) },
        ])
    }
}

enum MenuEntry {
    case item(String, @MainActor () -> Void)
    case separator
}

extension NSMenu {
    @MainActor
    static func build(_ entries: [MenuEntry]) -> NSMenu {
        let menu = NSMenu()
        for entry in entries {
            switch entry {
            case .item(let title, let action): menu.addItem(ClosureMenuItem(title: title, action: action))
            case .separator: menu.addItem(.separator())
            }
        }
        return menu
    }
}

@MainActor
final class ClosureMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(title: String, action handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func invoke() {
        handler()
    }
}
