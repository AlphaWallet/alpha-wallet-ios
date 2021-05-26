// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

struct GetERC721TokenUri {
    let abi = "[ { \"constant\": true, \"inputs\": [ {\"name\": \"\",\"type\": \"uint256\"}, ], \"name\": \"tokenURI\", \"outputs\": [{\"name\": \"\", \"type\": \"string\"}], \"type\": \"function\" } ]\n"
    let name = "tokenURI"
}

struct GetERC721Uri {
    let abi = "[ { \"constant\": true, \"inputs\": [ {\"name\": \"\",\"type\": \"uint256\"}, ], \"name\": \"uri\", \"outputs\": [{\"name\": \"\", \"type\": \"string\"}], \"type\": \"function\" } ]\n"
    let name = "uri"
}