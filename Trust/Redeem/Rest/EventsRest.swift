//
//  EventsRest.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/11/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import Result

public class EventsRest {

    func getEvents(completion: @escaping (Result<[Event], AnyError>) -> Void) {
        RestClient.get(endPoint: EndPoints.EventBaseUrl, completion: { response in
            print(response)
            guard let statusCode = response.response?.statusCode else {
                completion(.failure(AnyError(response.error!)))
                return
            }
            guard let jsonData = response.data else {
                completion(.failure(AnyError(RestError.invalidResponse("JSON is invalid"))))
                return
            }

            if 200...299 ~= statusCode { // success
                guard let events: [Event] = Event.from(data: jsonData) else {
                    completion(.failure(AnyError(RestError.invalidResponse("Could not parse data"))))
                    return
                }
                completion(.success(events))
            } else {
                completion(.failure(AnyError(RestError.invalidResponse("Could not parse data"))))
            }
        })
    }
}
