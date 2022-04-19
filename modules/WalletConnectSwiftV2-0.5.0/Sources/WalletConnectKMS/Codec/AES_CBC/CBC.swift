//
//  CBC.swift
//  CBC
//
//  Created by Gal Yedidovich on 01/08/2021.
//

import Foundation
import CryptoKit
import CommonCrypto

public extension AES {
    /// The Advanced Encryption Standard (AES) Cipher Block Chaining (CBC) cipher suite.
    enum CBC {
        public static var pkcs7Padding: CCOptions { CCOptions(kCCOptionPKCS7Padding) }

        /// Encrypt data with AES-CBC algorithm
        /// - Parameters:
        ///   - data: the data to encrypt
        ///   - key: a symmetric key for encryption
        ///   - iv: initial vector data
        /// - Throws: when fails to encrypt
        /// - Returns: encrypted data
        public static func encrypt(_ data: Data, using key: SymmetricKey, iv: Data, options: CCOptions = pkcs7Padding) throws -> Data {
            try process(data, using: key, iv: iv, operation: .encrypt, options: options)
        }

        /// Decrypts encrypted data with AES-CBC algorithm
        /// - Parameters:
        ///   - data: encrypted data to decrypt
        ///   - key: a symmetric key for encryption
        ///   - iv: initial vector data
        /// - Throws: when fails to decrypt
        /// - Returns: clear text data after decryption
        public static func decrypt(_ data: Data, using key: SymmetricKey, iv: Data, options: CCOptions = pkcs7Padding) throws -> Data {
            try process(data, using: key, iv: iv, operation: .decrypt, options: options)
        }

        /// Process data, either encrypt or decrypt it
        private static func process(_ data: Data, using key: SymmetricKey, iv: Data, operation: Operation, options: CCOptions) throws -> Data {
            let inputBuffer = data.bytes
            let keyData = key.dataRepresentation.bytes
            let ivData = iv.bytes

            let bufferSize = inputBuffer.count + kCCBlockSizeAES128
            var outputBuffer = [UInt8](repeating: 0, count: bufferSize)
            var numBytesProcessed = 0

            let cryptStatus = CCCrypt(
                operation.operation, CCAlgorithm(kCCAlgorithmAES), options, //params
                keyData, keyData.count, ivData, inputBuffer, inputBuffer.count, //input data
                &outputBuffer, bufferSize, &numBytesProcessed //output data
            )

            guard cryptStatus == CCCryptorStatus(kCCSuccess) else {
                throw CBCError(message: "Operation Failed", status: cryptStatus)
            }

            outputBuffer.removeSubrange(numBytesProcessed..<outputBuffer.count) //trim extra padding
            return Data(outputBuffer)
        }

        public enum Operation {
            case encrypt
            case decrypt

            internal var operation: CCOperation {
                CCOperation(self == .encrypt ? kCCEncrypt : kCCDecrypt)
            }
        }
    }
}
