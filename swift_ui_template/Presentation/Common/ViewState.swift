import Foundation

/// Loading state of one screen or section.
enum ViewState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

extension ViewState: Equatable where Value: Equatable {}
