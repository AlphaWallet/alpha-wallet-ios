// Copyright SIX DAY LLC. All rights reserved.

import Foundation


public class SignOrders
{
    //TODO get current account and assign it for signing
    //private let account : Account = Account.init()
    public static let CONTRACT_ADDR : String = "0xd9864b424447B758CdE90f8655Ff7cA4673956bf"

    //takes a list of orders and returns a list of signature objects
    func signOrder(orders : Array<Order>, account: Account) -> List<Result<Data, KeystoreError>>
    {
        var signatureObjects : Array<Result<Data, KeystoreError>>
        //EtherKeystore.signMessage(encodeMessage(), )
        for i in orders.length
        {
            //sign each order
            //TODO check casting to string
            var message = encodeMessageForTrade(price: orders.get(i).price,
                    expiryTimestamp: orders.get(i).expiryTimeStamp, tickets: orders.get(i).ticketIndices) as String
            var signedOrder = EtherKeystore.signMessage(message, self.account, false)
            signatureObjects.add(signedOrder)
        }
        return signatureObjects
    }
    
    
    func encodeMessageForTrade(price : BigInt, expiryTimestamp : BigInt, tickets : [ushort]) -> [byte]
    {
        var priceInWei : [byte] = price.toByteArray();
        var expiry : [byte] = expiryTimestamp.toByteArray();
        var message : [byte] = ByteBuffer.allocate(84 + tickets.length * 2);
        var leadingZeros : [byte] = [32 - priceInWei.length];
        message.put(leadingZeros);
        message.put(priceInWei);
        var leadingZerosExpiry : [byte] = [32 - expiry.length];
        message.put(leadingZerosExpiry);
        message.put(expiry);
        var contract : [byte] = hexStringToBytes(CONTRACT_ADDR.substring(2));
        System.out.println("length of contract: " + contract.length);
        message.put(contract);
        var shortBuffer = message.slice().asShortBuffer();
        shortBuffer.put(tickets);

        return message.array();
    }

    func hexStringToByteArray(hexString : String) -> [byte]
    {
        var cleanInput : String = cleanHexPrefix(input);

        var len = cleanInput.length();

        if len == 0 {
            return byte[]{};
        }

        var data;
        var startIdx;
        if len % 2 != 0
        {
            data = byte[(len / 2) + 1];
            data[0] = Character.digit(cleanInput.charAt(0), 16);
            startIdx = 1;
        }
        else
        {
            data = byte[len / 2];
            startIdx = 0;
        }

        var i = startIdx
        while i < len
        {
            data[(i + 1) / 2] = (byte) ((Character.digit(cleanInput.charAt(i), 16) << 4)
            + Character.digit(cleanInput.charAt(i + 1), 16))
            i += 2
        }

        return data;
    }

}
