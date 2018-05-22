//
//  RestClient.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/11/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import Alamofire

enum RestError: Error {
    case invalidResponse(String)
}

struct RestClient {

    static func get(endPoint: String,
                    parameters: [String: AnyHashable]? = nil,
                    completion: @escaping (_ response: DataResponse<Any>) -> Void) {
        // TODO: params
        Alamofire.request(endPoint, method: .get).responseJSON { response in
            completion(response)
        }
    }

    static func cancel() {
        Alamofire.SessionManager.default.session.getTasksWithCompletionHandler { (sessionDataTask, uploadData, downloadData) in
            sessionDataTask.forEach { $0.cancel() }
            uploadData.forEach { $0.cancel() }
            downloadData.forEach { $0.cancel() }
        }
    }

}
