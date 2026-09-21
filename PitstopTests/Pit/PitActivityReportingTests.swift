import Foundation
@testable import Pitstop
import Testing

/// An idle loop that waits instead of spinning: a sleep that returns at once would never let the main
/// actor go while Pit is idle.
private let parked: @Sendable (TimeInterval) async throws -> Void = { _ in
    try await Task.sleep(for: .seconds(3600))
}

@Suite("Pit activity sources")
struct PitActivitySourcesTests {
    @Test("ADR-0019: a report adds the source's activity and withdrawing it returns the interface to idle")
    func reportAndWithdraw() {
        var sources = PitActivitySources()
        let editor = PitActivitySource.unique()

        sources.report(.modalTask, from: editor)
        #expect(sources.activity == .modalTask)

        sources.withdraw(editor)
        #expect(sources.activity == .idle && sources.isEmpty)
    }

    @Test("ADR-0019: overlapping sources stay busy until the last one is withdrawn")
    func overlappingSources() {
        var sources = PitActivitySources()
        let first = PitActivitySource.unique()
        let second = PitActivitySource.unique()

        sources.report(.editing, from: first)
        sources.report(.editing, from: second)
        sources.report(.scrolling, from: .utilitySheet)
        sources.withdraw(first)
        #expect(sources.activity == [.editing, .scrolling])

        sources.withdraw(.utilitySheet)
        #expect(sources.activity == .editing)
        sources.report([], from: second)
        #expect(sources.activity == .idle && sources.isEmpty)
    }

    @Test("ADR-0019: a report replaces the source's previous one; repeating it never needs two withdrawals")
    func reportReplacesAndDoesNotCount() {
        var sources = PitActivitySources()
        let sheet = PitActivitySource.unique()

        sources.report(.modalTask, from: sheet)
        sources.report(.modalTask, from: sheet)
        sources.report(.capturing, from: sheet)
        #expect(sources.activity == .capturing)

        sources.withdraw(sheet)
        #expect(sources.activity == .idle)
    }

    @Test("ADR-0019: withdrawing a source that never reported, or twice, changes nothing")
    func withdrawalIsIdempotent() {
        var sources = PitActivitySources()
        let editor = PitActivitySource.unique()
        sources.report(.editing, from: editor)

        sources.withdraw(.unique())
        sources.withdraw(.utilitySheet)
        #expect(sources.activity == .editing)
        sources.withdraw(editor)
        sources.withdraw(editor)
        #expect(sources.activity == .idle)
    }
}

@MainActor
@Suite("Pit activity reporting")
struct PitActivityReportingTests {
    /// Every draw is a blink, and every sleep yields, so the idle loop runs as often as the test lets it.
    private func blinkingModel(_ shown: ShownStates) -> PitPresenceModel {
        PitPresenceModel(
            scheduler: PitIdleScheduler { 0.0 },
            sleep: { _ in await Task.yield() },
            onShow: shown.append
        )
    }

    private func settle() async {
        for _ in 0 ..< 60 {
            await Task.yield()
        }
    }

    @Test(
        "REQ-PIT-005: idle motion stops while the user scrolls, edits, or works in a sheet, and resumes after",
        arguments: [PitActivity.scrolling, .editing, .modalTask]
    )
    func idleLoopStopsAndResumes(activity: PitActivity) async {
        let shown = ShownStates()
        let pit = blinkingModel(shown)
        let source = PitActivitySource.unique()

        pit.report([], from: .utilitySheet)
        await settle()
        #expect(shown.states.contains(.blink))

        pit.report(activity, from: source)
        shown.clear()
        await settle()
        #expect(shown.states.isEmpty)
        #expect(pit.state == .resting && pit.activity == activity)

        pit.report([], from: source)
        await settle()
        #expect(shown.states.contains(.blink))
        pit.stop()
    }

    @Test("REQ-PIT-005: idle motion stays stopped while any one of several surfaces is still busy")
    func overlappingSurfacesKeepPitStill() async {
        let shown = ShownStates()
        let pit = blinkingModel(shown)
        let editor = PitActivitySource.unique()
        let field = PitActivitySource.unique()

        pit.report([], from: .utilitySheet)
        await settle()
        #expect(shown.states.contains(.blink))

        pit.report(.modalTask, from: editor)
        pit.report(.editing, from: field)
        pit.report([], from: field)
        shown.clear()
        await settle()
        #expect(shown.states.isEmpty && pit.activity == .modalTask)

        pit.report([], from: editor)
        await settle()
        #expect(shown.states.contains(.blink))
        pit.stop()
    }

    @Test("ADR-0019: the interface is idle only when no surface reports; Reduce Motion and a question do not count")
    func interfaceIdleIgnoresPitOwnState() async {
        let pit = PitPresenceModel(sleep: parked)
        let list = PitActivitySource.unique()
        pit.setReduceMotion(true)
        await pit.askPermissionToInterrupt()
        #expect(pit.isInterfaceIdle)

        pit.report(.scrolling, from: list)
        #expect(!pit.isInterfaceIdle)
        pit.report([], from: list)
        #expect(pit.isInterfaceIdle)
        pit.stop()
    }

    @Test("REQ-PIT-017: a surface report never clears Reduce Motion, and a closed sheet never clears a scroll")
    func reportsDoNotClearOtherState() {
        let pit = PitPresenceModel(sleep: parked)
        let list = PitActivitySource.unique()
        pit.setReduceMotion(true)

        pit.report(.scrolling, from: list)
        pit.report(.modalTask, from: .utilitySheet)
        pit.report([], from: .utilitySheet)

        #expect(pit.activity == [.reduceMotion, .scrolling])
        pit.report([], from: list)
        #expect(pit.activity == .reduceMotion)
        pit.stop()
    }

    @Test("ADR-0019: the environment reporter forwards a surface's report to Pit")
    func reporterForwardsToPit() {
        let pit = PitPresenceModel(sleep: parked)
        let reporter = PitActivityReporter.forwarding(to: pit)
        let sheet = PitActivitySource.unique()

        reporter(.modalTask, from: sheet)
        #expect(pit.activity == .modalTask)
        reporter([], from: sheet)
        #expect(pit.activity == .idle)

        PitActivityReporter.none(.modalTask, from: sheet)
        #expect(pit.activity == .idle)
        pit.stop()
    }
}

extension PitQuestionViewModelTests {
    @Test("REQ-PIT-006: Pit does not ask while an editor sheet is open, and may once it closes")
    func editorSheetBlocksTheQuestion() async throws {
        let (store, questions) = try await makeStores()
        let moment = now
        let model = try PitQuestionViewModel(
            questions: questions, store: store, registry: PitQuestionRegistry.product(), now: { moment }
        )
        let pit = PitPresenceModel(sleep: parked)
        let reporter = PitActivityReporter.forwarding(to: pit)
        let editor = PitActivitySource.unique()

        reporter(.modalTask, from: editor)
        #expect(await !model.evaluate(context: .service) { pit.activity })
        #expect(model.phase == .silent)
        #expect(await questions.executed.isEmpty)

        reporter([], from: editor)
        #expect(await model.evaluate(context: .service) { pit.activity })
        pit.stop()
    }

    @Test("REQ-PIT-006: Pit does not ask while a text field is focused, even with Reduce Motion on")
    func focusedFieldBlocksTheQuestion() async throws {
        let (store, questions) = try await makeStores()
        let moment = now
        let model = try PitQuestionViewModel(
            questions: questions, store: store, registry: PitQuestionRegistry.product(), now: { moment }
        )
        let pit = PitPresenceModel(sleep: parked)
        pit.setReduceMotion(true)
        pit.report(.editing, from: .unique())

        #expect(await !model.evaluate(context: .service) { pit.activity })
        #expect(await questions.executed.isEmpty)
        pit.stop()
    }

    @Test("ADR-0019, REQ-PIT-006: a scroll at the ask moment defers the question until the interface settles again")
    func questionReturnsAfterScrollingStops() async throws {
        let (store, questions) = try await makeStores()
        let moment = now
        let model = try PitQuestionViewModel(
            questions: questions, store: store, registry: PitQuestionRegistry.product(), now: { moment }
        )
        let pit = PitPresenceModel(sleep: parked)
        let path: [CarBoardRoute] = [.tile(.service)]
        let list = PitActivitySource.unique()
        var settles = 0
        var asked = false
        func run(_ trigger: PitAskTrigger) async {
            await trigger.run(
                settle: { settles += 1 },
                ask: { asked = await model.evaluate(context: .service) { pit.activity } }
            )
        }

        // Arrived idle, but the list is still moving when the settle delay ends: the view's check sees it.
        let arrival = PitAskTrigger(path: path, isInterfaceIdle: true)
        pit.report(.scrolling, from: list)
        await run(arrival)
        #expect(!asked && model.phase == .silent)

        // The scroll report changes the trigger; while busy it neither settles nor asks.
        let busy = PitAskTrigger(path: path, isInterfaceIdle: pit.isInterfaceIdle)
        #expect(busy != arrival)
        await run(busy)
        #expect(!asked && settles == 1)

        // The scroll stops: a new trigger, a fresh settle delay, and then the question.
        pit.report([], from: list)
        let settled = PitAskTrigger(path: path, isInterfaceIdle: pit.isInterfaceIdle)
        #expect(settled != busy)
        await run(settled)
        #expect(settles == 2)
        #expect(asked && model.isAsking)
        pit.stop()
    }

    @Test("ADR-0019: a check cancelled during its settle delay asks nothing")
    func cancelledSettleDoesNotAsk() async {
        var asked = false
        await PitAskTrigger(path: [], isInterfaceIdle: true).run(
            settle: { throw CancellationError() },
            ask: { asked = true }
        )
        #expect(!asked)
    }
}

@MainActor
private final class ShownStates {
    private(set) var states: [PitState] = []

    func append(_ state: PitState) {
        states.append(state)
    }

    func clear() {
        states.removeAll()
    }
}
