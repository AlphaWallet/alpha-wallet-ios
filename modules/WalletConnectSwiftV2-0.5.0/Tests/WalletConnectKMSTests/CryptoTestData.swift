// 

import Foundation

enum CryptoTestData {
    static let _privateKeyA = Data(hex: "1fb63fca5c6ac731246f2f069d3bc2454345d5208254aa8ea7bffc6d110c8862")
    static let _publicKeyA = Data(hex: "ff7a7d5767c362b0a17ad92299ebdb7831dcbd9a56959c01368c7404543b3342")
    static let _privateKeyB = Data(hex: "36bf507903537de91f5e573666eaa69b1fa313974f23b2b59645f20fea505854")
    static let _publicKeyB = Data(hex: "590c2c627be7af08597091ff80dd41f7fa28acd10ef7191d7e830e116d3a186a")
    static let expectedSharedSecret = Data(hex: "9c87e48e69b33a613907515bcd5b1b4cc10bbaf15167b19804b00f0a9217e607")
}
