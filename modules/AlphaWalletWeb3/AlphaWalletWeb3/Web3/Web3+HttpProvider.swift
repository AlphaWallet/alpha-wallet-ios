//
//  Web3+Provider.swift
//  web3swift
//
//  Created by Alexander Vlasov on 19.12.2017.
//  Copyright © 2017 Bankex Foundation. All rights reserved.
//

import Foundation
import BigInt
import PromiseKit

public protocol Web3RequestProvider {
    func sendAsync(_ request: JSONRPCrequest, queue: DispatchQueue) -> Promise<JSONRPCresponse>
    func sendAsync(_ requests: JSONRPCrequestBatch, queue: DispatchQueue) -> Promise<JSONRPCresponseBatch>
}

public class Web3HttpProvider: Web3RequestProvider {
    public let headers: RPCNodeHTTPHeaders
    public let url: URL
    public var session: URLSession = {
        let config = URLSessionConfiguration.default
        let urlSession = URLSession(configuration: config)
        return urlSession
    }()

    public init?(_ url: URL, headers: RPCNodeHTTPHeaders) {
        guard url.scheme == "http" || url.scheme == "https" else { return nil }
        self.headers = headers
        self.url = url
    }

    private static func generateBasicAuthCredentialsHeaderValue(fromURL url: URL) -> String? {
        guard let username = url.user, let password = url.password  else { return nil }
        return Data("\(username):\(password)".utf8).base64EncodedString()
    }

    private static func urlRequest<T: Encodable>(for request: T, providerURL: URL, headers: RPCNodeHTTPHeaders, using decoder: JSONEncoder = JSONEncoder()) throws -> URLRequest {
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)
        var urlRequest = URLRequest(url: providerURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let basicAuth = generateBasicAuthCredentialsHeaderValue(fromURL: providerURL) {
            urlRequest.setValue("Basic \(basicAuth)", forHTTPHeaderField: "Authorization")
        }
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        urlRequest.httpBody = requestData

        return urlRequest
    }

    private static func dataTask<T: Encodable>(for request: T, providerURL: URL, headers: RPCNodeHTTPHeaders, using decoder: JSONEncoder = JSONEncoder(), queue: DispatchQueue = .main, session: URLSession) -> Promise<Swift.Result<Data, Web3Error>> {
        let promise = Promise<Swift.Result<Data, Web3Error>>.pending()
        var task: URLSessionTask?
        queue.async {
            do {
                let urlRequest = try Web3HttpProvider.urlRequest(for: request, providerURL: providerURL, headers: headers)
                task = session.dataTask(with: urlRequest) { (data, response, error) in
                    let result: Swift.Result<Data, Web3Error>

                    switch (data, response, error) {
                    case (_, _, let error?):
                        result = .failure(.connectionError(error))
                    case (let data?, let urlResponse as HTTPURLResponse, _):
                        if urlResponse.statusCode == 429 {
                            result = .failure(.rateLimited)
                        } else {
                            if data.isEmpty {
                                result = .failure(Web3Error.responseError(URLError(.zeroByteResource)))
                            } else {
                                result = .success(data)
                            }
                        }
                    default:
                        result = .failure(.responseError(URLError(.unknown)))
                    }

                    promise.resolver.fulfill(result)
                }
                task?.resume()
            } catch {
                promise.resolver.reject(error)
            }
        }

        return promise.promise.ensure(on: queue) { task = nil }
    }

    static func post(_ request: JSONRPCrequest, providerURL: URL, headers: RPCNodeHTTPHeaders, queue: DispatchQueue = .main, session: URLSession) -> Promise<JSONRPCresponse> {
        return Web3HttpProvider.dataTask(for: request, providerURL: providerURL, headers: headers, queue: queue, session: session)
            .map(on: queue) { result throws -> JSONRPCresponse in
                switch result {
                case .success(let data):
                    do {
                        let parsedResponse = try JSONDecoder().decode(JSONRPCresponse.self, from: data)
                        return parsedResponse
                    } catch {
                        throw Web3Error.responseError(error)
                    }
                case .failure(let error):
                    throw error
                }
            }
    }

    static func post(_ request: JSONRPCrequestBatch, providerURL: URL, headers: RPCNodeHTTPHeaders, queue: DispatchQueue = .main, session: URLSession) -> Promise<JSONRPCresponseBatch> {
        return Web3HttpProvider.dataTask(for: request, providerURL: providerURL, headers: headers, queue: queue, session: session)
            .map(on: queue) { result throws -> JSONRPCresponseBatch in
                switch result {
                case .success(let data):
                    do {
                        let response = try JSONDecoder().decode(JSONRPCresponseBatch.self, from: data)
                        return response
                    } catch {
                        do {
                            let parsedResponse = try JSONDecoder().decode(JSONRPCresponse.self, from: data)
                            return JSONRPCresponseBatch(responses: [parsedResponse])
                        } catch {
                            throw Web3Error.responseError(error)
                        }
                    }
                case .failure(let error):
                    throw error
                }
            }
    }

    public func sendAsync(_ request: JSONRPCrequest, queue: DispatchQueue = .main) -> Promise<JSONRPCresponse> {
        return Web3HttpProvider.post(request, providerURL: url, headers: headers, queue: queue, session: session)
    }

    public func sendAsync(_ requests: JSONRPCrequestBatch, queue: DispatchQueue = .main) -> Promise<JSONRPCresponseBatch> {
        return Web3HttpProvider.post(requests, providerURL: url, headers: headers, queue: queue, session: session)
    }
}

