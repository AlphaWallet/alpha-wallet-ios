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
        let endpoint = EndPoints.EventBaseUrl + "/" + address.description.lowercased()
        print(endpoint)
        RestClient.get(endPoint: endpoint, completion: { response in

            guard let statusCode = response.response?.statusCode else {
                completion(.failure(AnyError(response.error!)))
                return
            }

            if 200...299 ~= statusCode { // success
                completion(.success([]))
            } else {
                //String not displayed to user
                completion(.failure(AnyError(RestError.invalidResponse("Could not parse data"))))
            }
        })
    }
}
