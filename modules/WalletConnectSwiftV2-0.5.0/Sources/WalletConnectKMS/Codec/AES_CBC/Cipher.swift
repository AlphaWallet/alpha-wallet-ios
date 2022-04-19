//
//  Cipher.swift
//  CBC
//
//  Created by Gal Yedidovich on 02/08/2021.
//

import Foundation
import CryptoKit
import CommonCrypto

extension AES.CBC {
    /// Advanced Cipher, provides incremental crypto operation (encryption/decryption) on data.
    public class Cipher {
        private let context: CCCryptorRef
        private var buffer = Data()

        /// Initialize new cipher instance that can operate on data to either encrypt or decrypt it.
        /// - Parameters:
        ///   - operation: the cryptografic operation
        ///   - key: a symmetric key for operation
        ///   - iv: initial vector data
        /// - Throws: when fails to create a cryptografic context
        public init(_ operation: Operation, using key: SymmetricKey, iv: Data, options: CCOptions = pkcs7Padding) throws {
            let keyData = key.dataRepresentation.bytes
            let ivData = iv.bytes
            var cryptorRef: CCCryptorRef?
            let status = CCCryptorCreate(
                operation.operation, CCAlgorithm(kCCAlgorithmAES), options,
                keyData, keyData.count, ivData, &cryptorRef)

            guard status == CCCryptorStatus(kCCSuccess), let cryptor = cryptorRef else {
                throw CBCError(message: "Could not create cryptor", status: status)
            }

            context = cryptor
        }

        /// releases the crypto context
        deinit {
            CCCryptorRelease(context)
        }

        /// updates the cipher with data.
        ///
        /// - Parameter data: input data to process
        /// - Throws: an error when failing to process the data
        /// - Returns: processed data, after crypto operation (encryption/decryption)
        public func update(_ data: Data) throws -> Data {
            let outputLength = CCCryptorGetOutputLength(context, data.count, false)
            buffer.count = outputLength
            var dataOutMoved = 0

            let rawData = data.bytes
            let status = buffer.withUnsafeMutableBytes { bufferPtr in
                CCCryptorUpdate(context, rawData, rawData.count, bufferPtr.baseAddress!, outputLength, &dataOutMoved)
            }

            guard status == CCCryptorStatus(kCCSuccess) else {
                throw CBCError(message: "Could not update", status: status)
            }

            buffer.count = dataOutMoved
            return buffer
        }

        /// finalizing the crypto process on the internal buffer.
        ///
        /// after this call the internal buffer resets.
        /// - Throws: an error when failing to process the data
        /// - Returns: the remaining data to process. possible to be just the padding
        public func finalize() throws -> Data {
            let outputLength = CCCryptorGetOutputLength(context, 0, true)
            var dataOutMoved = 0

            let status = buffer.withUnsafeMutableBytes { bufferPtr in
                CCCryptorFinal(context, bufferPtr.baseAddress!, outputLength, &dataOutMoved)
            }

            guard status == CCCryptorStatus(kCCSuccess) else {
                throw CBCError(message: "Could not finalize", status: status)
            }

            buffer.count = dataOutMoved
            defer { buffer = Data() }
            return buffer
        }
    }
}
