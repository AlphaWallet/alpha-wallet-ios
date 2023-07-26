// Copyright © 2023 Stormbird PTE. LTD.

public extension Dictionary {
    public func tap(block: (Self) -> Void) -> Self {
        block(self)
        return self
    }
}
