// TODO: Refactor into codes. Reference: https://docs.walletconnect.com/2.0/protocol/reason-codes
public struct Reason {
    
    public let code: Int
    public let message: String
    
    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}
