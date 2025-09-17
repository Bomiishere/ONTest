//
//  MatchListDiffer.swift
//  ONTest
//
//  Created by bomi on 2025/9/15.
//

import Dependencies

actor MatchListDiffer {
    func patch(existing: [MatchListFeature.State.Row], new: [MatchListFeature.State.Row]) -> MatchListPatch {
        let oldIDs = existing.map { $0.id }
        let newIDs = new.map { $0.id }

        let difference = newIDs.difference(from: oldIDs, by: ==).inferringMoves()

        var removals: [Int] = []
        var insertions: [(Int, MatchListFeature.State.Row)] = []

        for change in difference {
            switch change {
            case let .remove(offset, _, _):
                removals.append(offset)
            case let .insert(offset, element, _):
                if let rowIndex = newIDs.firstIndex(of: element) {
                    insertions.append((offset, new[rowIndex]))
                }
            }
        }
        
        print("MatchListPatch removals.count: \(removals.count), insertions.count: \(insertions.count)")
        return MatchListPatch(removals: removals, insertions: insertions)
    }
    
    deinit { print("deinit MatchListDiffer") }
}

// MARK: Client
struct MatchListDifferClient {
    var patch:  @Sendable ([MatchListFeature.State.Row], [MatchListFeature.State.Row]) async -> MatchListPatch
}

extension MatchListDifferClient: DependencyKey {
    static let liveValue: MatchListDifferClient = {
        let differ = MatchListDiffer()
        return .init(
            patch: { existing, new in
                await differ.patch(existing: existing, new: new)
            }
        )
    }()

    static let previewValue: MatchListDifferClient = .init(
        patch:  { _, new in MatchListPatch(removals: [], insertions: new.enumerated().map { ($0.offset, $0.element) }) }
    )

    static let testValue: MatchListDifferClient = .init(
        patch:  { _, new in MatchListPatch(removals: [], insertions: new.enumerated().map { ($0.offset, $0.element) }) }
    )
}

extension DependencyValues {
    var matchListDiffer: MatchListDifferClient {
        get { self[MatchListDifferClient.self] }
        set { self[MatchListDifferClient.self] = newValue }
    }
}

//MARK: Model
struct MatchListPatch: Equatable, Sendable {
    var removals: [Int]
    var insertions: [(Int, MatchListFeature.State.Row)]
    
    static func == (lhs: MatchListPatch, rhs: MatchListPatch) -> Bool {
        lhs.removals == rhs.removals &&
        lhs.insertions.elementsEqual(rhs.insertions, by: { l, r in
            l.0 == r.0 && l.1 == r.1
        })
    }
}
