//
//  Alamofire+Publishers.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Combine
import PromiseKit
import Alamofire

public enum PromiseError: Error {
    case some(error: Error)
}

public struct DataResponse {
    public init<T>(_ rawrsp: Alamofire.DataResponse<T>) {
        request = rawrsp.request
        response = rawrsp.response
        data = rawrsp.data
        timeline = rawrsp.timeline
    }

    /// The URL request sent to the server.
    public let request: URLRequest?

    /// The server's response to the URL request.
    public let response: HTTPURLResponse?

    /// The data returned by the server.
    public let data: Data?

    /// The timeline of the complete lifecycle of the request.
    public let timeline: Timeline
}

extension Alamofire.DataRequest {
    /// Adds a handler to be called once the request has finished.
    public func responseJSONPublisher(queue: DispatchQueue? = DispatchQueue.global(), options: JSONSerialization.ReadingOptions = .allowFragments) -> AnyPublisher<(json: Any, response: DataResponse), PromiseError> {
        var dataRequest: DataRequest?
        let publisher = Future<(json: Any, response: DataResponse), PromiseError> { seal in
            dataRequest = self.responseJSON(queue: queue, options: options) { response in
                switch response.result {
                case .success(let value):
                    seal(.success((value, DataResponse(response))))
                case .failure(let error):
                    seal(.failure(.some(error: error)))
                }
            }
        }.handleEvents(receiveCancel: {
            dataRequest?.cancel()
        })

        return publisher
            .eraseToAnyPublisher()
    }

    /// Adds a handler to be called once the request has finished.
    public func responseDataPublisher(queue: DispatchQueue? = DispatchQueue.global()) -> AnyPublisher<(data: Data, response: DataResponse), PromiseError> {
        var dataRequest: DataRequest?
        let publisher = Future<(data: Data, response: DataResponse), PromiseError> { seal in
            dataRequest = self.responseData(queue: queue) { response in
                switch response.result {
                case .success(let value):
                    seal(.success((value, DataResponse(response))))
                case .failure(let error):
                    seal(.failure(.some(error: error)))
                }
            }
        }.handleEvents(receiveCancel: {
            dataRequest?.cancel()
        })

        return publisher
            .eraseToAnyPublisher()
    }
}
