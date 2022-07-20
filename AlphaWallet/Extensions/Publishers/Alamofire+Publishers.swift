//
//  Alamofire+Publishers.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Combine
import PromiseKit
import Alamofire

extension Alamofire.DataRequest {
    /// Adds a handler to be called once the request has finished.
    public func responseJSONPublisher(queue: DispatchQueue? = DispatchQueue.global(), options: JSONSerialization.ReadingOptions = .allowFragments) -> AnyPublisher<(json: Any, response: PMKAlamofireDataResponse), PromiseError> {
        var dataRequest: DataRequest?
        let publisher = Future<(json: Any, response: PMKAlamofireDataResponse), PromiseError> { seal in
            dataRequest = self.responseJSON(queue: queue, options: options) { response in
                switch response.result {
                case .success(let value):
                    seal(.success((value, PMKAlamofireDataResponse(response))))
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
    public func responseDataPublisher(queue: DispatchQueue? = DispatchQueue.global()) -> AnyPublisher<(data: Data, response: PMKAlamofireDataResponse), PromiseError> {
        var dataRequest: DataRequest?
        let publisher = Future<(data: Data, response: PMKAlamofireDataResponse), PromiseError> { seal in
            dataRequest = self.responseData(queue: queue) { response in
                switch response.result {
                case .success(let value):
                    seal(.success((value, PMKAlamofireDataResponse(response))))
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
