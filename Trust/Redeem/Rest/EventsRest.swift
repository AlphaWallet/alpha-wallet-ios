//
//  EventsRest.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/11/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import Result
import TrustKeystore

public class EventsRest {

    func getEvents(for address: Address,
                   completion: @escaping (Result<[Event], AnyError>) -> Void) {
        let endpoint = EndPoints.EventBaseUrl + "/" + address.description
        RestClient.get(endPoint: endpoint, completion: { response in
            print(response)
            guard let statusCode = response.response?.statusCode else {
                completion(.failure(AnyError(response.error!)))
                return
            }
            // TODO: Fix this
//            guard let jsonData = response.data else {
//                completion(.failure(AnyError(RestError.invalidResponse("JSON is invalid"))))
//                return
//            }

            if 200...299 ~= statusCode { // success
//                guard let events: [Event] = Event.from(data: jsonData) else {
//                    completion(.failure(AnyError(RestError.invalidResponse("Could not parse data"))))
//                    return
//                }
                completion(.success([]))
            } else {
                completion(.failure(AnyError(RestError.invalidResponse("Could not parse data"))))
            }
        })
    }
}
