//
//  AssetDefinitionXML.swift
//  AlphaWallet
//
//  Created by James Sangalli on 11/4/18.
//

import Foundation 

public class AssetDefinitionXML {
    public var assetDefinitionString = ""
    init() {
        if let path = Bundle.main.path(forResource: "TicketingContract", ofType: "xml", inDirectory: "contracts") {
            assetDefinitionString = try! String(contentsOf: URL(string: "file://" + path)!)
        }
    }
}

