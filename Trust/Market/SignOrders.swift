// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public class SignOrders
{
    //takes a list of orders and returns a list of signature objects
    func signOrder(orders : List<Order>, account: Account) -> List<Result<Data, KeystoreError>
    {
        var signatureObjects : List<Result<Data, KeystoreError>>
        //EtherKeystore.signMessage(encodeMessage(), )
        for(int i = 0; i < orders.length; i++)
        {
            //sign each order
            //signatureObjects.add(EtherKeystore.signMessage(encodeMessage(), ))
        }
        return signatureObjects
    }
    
    
//    public static byte[] encodeMessageForTrade(BigInteger price, BigInteger expiryTimestamp, short[] tickets)
//    {
//        byte[] priceInWei = price.toByteArray();
//        byte[] expiry = expiryTimestamp.toByteArray();
//        ByteBuffer message = ByteBuffer.allocate(84 + tickets.length * 2);
//        byte[] leadingZeros = new byte[32 - priceInWei.length];
//        message.put(leadingZeros);
//        message.put(priceInWei);
//        byte[] leadingZerosExpiry = new byte[32 - expiry.length];
//        message.put(leadingZerosExpiry);
//        message.put(expiry);
//        byte[] contract = hexStringToBytes(CONTRACT_ADDR.substring(2));
//        System.out.println("length of contract: " + contract.length);
//        message.put(contract);
//        ShortBuffer shortBuffer = message.slice().asShortBuffer();
//        shortBuffer.put(tickets);
//
//        return message.array();
//    }
//
    func encodeMessage(price : BigInt, expiryTimestamp : BigInt, tickets : (short[])) -> String
    {
        return ""
    }
}
