//
//  AssetDefinitionXML.swift
//  AlphaWallet
//
//  Created by James Sangalli on 11/4/18.
//

import Foundation 

// swiftlint:disable:next type_body_length
class AssetDefinitionXML {
    private static let xmlInputStream = InputStream(fileAtPath: "./contracts/AssetDefinition.xml")
    // swiftlint:disable:this
    public static let assetDefinition =     "<?xml version=\"1.0\" encoding=\"UTF-8\"  standalone=\"no\"?><asset><ds:Signature xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\">\n" +
    "<ds:SignedInfo>\n" +
    "<ds:CanonicalizationMethod Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"/>\n" +
    "<ds:SignatureMethod Algorithm=\"http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha256\"/>\n" +
    "<ds:Reference URI=\"\">\n" +
    "<ds:Transforms>\n" +
    "<ds:Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"/>\n" +
    "<ds:Transform Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"/>\n" +
    "</ds:Transforms>\n" +
    "<ds:DigestMethod Algorithm=\"http://www.w3.org/2001/04/xmlenc#sha256\"/>\n" +
    "<ds:DigestValue>yi3sBrV9UTzaB7aDhl/0xPbnPe+YGePWX3aE1pTl0tY=</ds:DigestValue>\n" +
    "</ds:Reference>\n" +
    "</ds:SignedInfo>\n" +
    "<ds:SignatureValue>\n" +
    "mlwDNqSphXenfoGeJwfum3XTj8NcMxpovL3FZk0JD4q9CzKsOr5cM+buB+aVZKv4gpX/FHnEVqer\n" +
    "mnikWTVS7hKohBfRwGadozeJglfx9DGc/x2IQIMQEt67e52HFXEICDLe5tlGMOgi5hzlI6vFKEpK\n" +
    "hjPhLxr2T0h2xf+NDc7RdQ==\n" +
    "</ds:SignatureValue>\n" +
    "<ds:KeyInfo>\n" +
    "<ds:X509Data>\n" +
    "<ds:X509Certificate>\n" +
    "MIIFBzCCBK2gAwIBAgIQKCMFmlBLtxz6L27XkUOsHjAKBggqhkjOPQQDAjCBkDELMAkGA1UEBhMC\n" +
    "R0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UE\n" +
    "ChMRQ09NT0RPIENBIExpbWl0ZWQxNjA0BgNVBAMTLUNPTU9ETyBFQ0MgRG9tYWluIFZhbGlkYXRp\n" +
    "b24gU2VjdXJlIFNlcnZlciBDQTAeFw0xODA1MTEwMDAwMDBaFw0xOTA1MTEyMzU5NTlaMFAxITAf\n" +
    "BgNVBAsTGERvbWFpbiBDb250cm9sIFZhbGlkYXRlZDEUMBIGA1UECxMLUG9zaXRpdmVTU0wxFTAT\n" +
    "BgNVBAMTDHNrc3RyYXZlbC5jbjCBmzAQBgcqhkjOPQIBBgUrgQQAIwOBhgAEADc2VNAGlEOcdqeU\n" +
    "A0vaxIC8gCFb9FDF8ZrrlJwqhpO/ZmnTCWUfe4LoI1a37Zv7QejC2+vPhyP0q55PvUtJT9INARfc\n" +
    "VaG5jRpTw3ukSF1+ww/E/T6YqtrRV44U7rSF8XPTH0CmDrJD6z/b2aCXwcix4PByn8O6skTdZXOj\n" +
    "LEXifqcjo4IC4zCCAt8wHwYDVR0jBBgwFoAUu/oI4L9U7lr9FqQ1AgmppMjs/UswHQYDVR0OBBYE\n" +
    "FGyswybdwCsAau7aZaBGFEcL2XXmMA4GA1UdDwEB/wQEAwIFgDAMBgNVHRMBAf8EAjAAMB0GA1Ud\n" +
    "JQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjBPBgNVHSAESDBGMDoGCysGAQQBsjEBAgIHMCswKQYI\n" +
    "KwYBBQUHAgEWHWh0dHBzOi8vc2VjdXJlLmNvbW9kby5jb20vQ1BTMAgGBmeBDAECATBUBgNVHR8E\n" +
    "TTBLMEmgR6BFhkNodHRwOi8vY3JsLmNvbW9kb2NhLmNvbS9DT01PRE9FQ0NEb21haW5WYWxpZGF0\n" +
    "aW9uU2VjdXJlU2VydmVyQ0EuY3JsMIGFBggrBgEFBQcBAQR5MHcwTwYIKwYBBQUHMAKGQ2h0dHA6\n" +
    "Ly9jcnQuY29tb2RvY2EuY29tL0NPTU9ET0VDQ0RvbWFpblZhbGlkYXRpb25TZWN1cmVTZXJ2ZXJD\n" +
    "QS5jcnQwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmNvbW9kb2NhLmNvbTApBgNVHREEIjAgggxz\n" +
    "a3N0cmF2ZWwuY26CEHd3dy5za3N0cmF2ZWwuY24wggEEBgorBgEEAdZ5AgQCBIH1BIHyAPAAdgDu\n" +
    "S723dc5guuFCaR+r4Z5mow9+X7By2IMAxHuJeqj9ywAAAWNOX8kpAAAEAwBHMEUCIEIb/jymAGpZ\n" +
    "LG4umW1TbfCe/7Sr5MEIYknkdRdd6I6qAiEA2pHlmnby7PaQwoZrFGqIPQEyJ6oChl+7VRrcoA4t\n" +
    "5JsAdgB0ftqDMa0zEJEhnM4lT0Jwwr/9XkIgCMY3NXnmEHvMVgAAAWNOX8mcAAAEAwBHMEUCIQC/\n" +
    "LOBZaO136CYN7GYr+OODcLZ/AG2r7ge7BigCRSk8fQIgC/n33uxEZD+w3ENTxTdOhCTxvSW6BL71\n" +
    "wFYJPkFHYWkwCgYIKoZIzj0EAwIDSAAwRQIhAIi6VxP/HzmR3rGw6f9M6FLiH0TNgn1EbARAluAV\n" +
    "bFTFAiBKJSQRqq66kI9yMPc1NJISGi8btpWfPiB78twtjuHe7A==\n" +
    "</ds:X509Certificate>\n" +
    "<ds:X509Certificate>\n" +
    "MIIDnTCCAyKgAwIBAgIQUQYB5jtQZzxV7k4Z2jBMqDAKBggqhkjOPQQDAzCBhTELMAkGA1UEBhMC\n" +
    "R0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UE\n" +
    "ChMRQ09NT0RPIENBIExpbWl0ZWQxKzApBgNVBAMTIkNPTU9ETyBFQ0MgQ2VydGlmaWNhdGlvbiBB\n" +
    "dXRob3JpdHkwHhcNMTQwMzEzMDAwMDAwWhcNMjkwMzEyMjM1OTU5WjCBkDELMAkGA1UEBhMCR0Ix\n" +
    "GzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMR\n" +
    "Q09NT0RPIENBIExpbWl0ZWQxNjA0BgNVBAMTLUNPTU9ETyBFQ0MgRG9tYWluIFZhbGlkYXRpb24g\n" +
    "U2VjdXJlIFNlcnZlciBDQTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABIg2jdgJVPWaKXk+JD06\n" +
    "oiTxihgKVH3tQCza8LqO2YT1Rd03cJEkrLoU61FoIN3SSFUAXW9E7ggci/lVXySaVIOjggFlMIIB\n" +
    "YTAfBgNVHSMEGDAWgBR1cacZSBm8nZ3qQUfflMRId5nTeTAdBgNVHQ4EFgQUu/oI4L9U7lr9FqQ1\n" +
    "AgmppMjs/UswDgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0lBBYwFAYI\n" +
    "KwYBBQUHAwEGCCsGAQUFBwMCMBsGA1UdIAQUMBIwBgYEVR0gADAIBgZngQwBAgEwTAYDVR0fBEUw\n" +
    "QzBBoD+gPYY7aHR0cDovL2NybC5jb21vZG9jYS5jb20vQ09NT0RPRUNDQ2VydGlmaWNhdGlvbkF1\n" +
    "dGhvcml0eS5jcmwwcQYIKwYBBQUHAQEEZTBjMDsGCCsGAQUFBzAChi9odHRwOi8vY3J0LmNvbW9k\n" +
    "b2NhLmNvbS9DT01PRE9FQ0NBZGRUcnVzdENBLmNydDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3Au\n" +
    "Y29tb2RvY2EuY29tMAoGCCqGSM49BAMDA2kAMGYCMQDtilgEuIgqZMub1nOMLJwPVr3Lrs/A4RVY\n" +
    "uImPsVNTtWG65FL7j6YooeQtlSxIViACMQDvavtMsSKuUzwaH3x8vVhGiljleoI0iloIE64Adby0\n" +
    "id6I7ObgYgAsmupHtaSvojI=\n" +
    "</ds:X509Certificate>\n" +
    "<ds:X509Certificate>\n" +
    "MIID0DCCArigAwIBAgIQQ1ICP/qokB8Tn+P05cFETjANBgkqhkiG9w0BAQwFADBvMQswCQYDVQQG\n" +
    "EwJTRTEUMBIGA1UEChMLQWRkVHJ1c3QgQUIxJjAkBgNVBAsTHUFkZFRydXN0IEV4dGVybmFsIFRU\n" +
    "UCBOZXR3b3JrMSIwIAYDVQQDExlBZGRUcnVzdCBFeHRlcm5hbCBDQSBSb290MB4XDTAwMDUzMDEw\n" +
    "NDgzOFoXDTIwMDUzMDEwNDgzOFowgYUxCzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1h\n" +
    "bmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGjAYBgNVBAoTEUNPTU9ETyBDQSBMaW1pdGVkMSsw\n" +
    "KQYDVQQDEyJDT01PRE8gRUNDIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MHYwEAYHKoZIzj0CAQYF\n" +
    "K4EEACIDYgAEA0d7L3XJghWF+3XkkRbUq2KZ9T5SCwbOQQB/l+EKJDwdAQTuPdKNCZcM4HXk+vt3\n" +
    "iir1A2BLNosWIxatCXH0SvQoULT+iBxuP2wvLwlZW6VbCzOZ4sM9iflqLO+y0wbpo4H+MIH7MB8G\n" +
    "A1UdIwQYMBaAFK29mHo0tCb3+sQmVO8DveAky1QaMB0GA1UdDgQWBBR1cacZSBm8nZ3qQUfflMRI\n" +
    "d5nTeTAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zARBgNVHSAECjAIMAYGBFUdIAAw\n" +
    "SQYDVR0fBEIwQDA+oDygOoY4aHR0cDovL2NybC50cnVzdC1wcm92aWRlci5jb20vQWRkVHJ1c3RF\n" +
    "eHRlcm5hbENBUm9vdC5jcmwwOgYIKwYBBQUHAQEELjAsMCoGCCsGAQUFBzABhh5odHRwOi8vb2Nz\n" +
    "cC50cnVzdC1wcm92aWRlci5jb20wDQYJKoZIhvcNAQEMBQADggEBAB3H+i5AtlwFSw+8VTYBWOBT\n" +
    "BT1k+6zZpTi4pyE7r5VbvkjI00PUIWxB7QktnHMAcZyuIXN+/46NuY5YkI78jG12yAA6nyCmLX3M\n" +
    "F/3NmJYyCRrJZfwE67SaCnjllztSjxLCdJcBns/hbWjYk7mcJPuWJ0gBnOqUP3CYQbNzUTcp6PYB\n" +
    "erknuCRR2RFo1KaFpzanpZa6gPim/a5thCCuNXZzQg+HCezF3OeTAyIal+6ailFhp5cmHunudVEI\n" +
    "kAWvL54TnJM/ev/m6+loeYyv4Lb67psSE/5FjNJ80zXrIRKT/mZ1JioVhCb3ZsnLjbsJQdQYr7Gz\n" +
    "EPUQyp2aDrV1aug=\n" +
    "</ds:X509Certificate>\n" +
    "</ds:X509Data>\n" +
    "</ds:KeyInfo>\n" +
    "</ds:Signature>\n" +
    "\t<contract type=\"issuing\">\n" +
    "\t\t<address network=\"1\">0xA66A3F08068174e8F005112A8b2c7A507a822335</address>\n" +
    "\t\t<address network=\"3\">0xD8e5F58DE3933E1E35f9c65eb72cb188674624F3</address>\n" +
    "\t\t<name lang=\"ru\">Билеты</name>\n" +
    "\t\t<name lang=\"en\">Tickets</name>\n" +
    "\t\t<name lang=\"zh\">票</name>\n" +
    "\t\t<name lang=\"es\">Entradas</name>\n" +
    "\t</contract>\n" +
    "  <!-- consider metadata of tokens, e.g. quantifier in each languages -->\n" +
    "  <features>\n" +
    "    <feature bitmask=\"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\">\n" +
    "      <trade method=\"market-queue\" version=\"0.1\"><gateway>https://482kdh4npg.execute-api.ap-southeast-1.amazonaws.com/dev/</gateway></trade>\n" +
    "      <trade method=\"universal-link\" version=\"9\"><prefix>https://app.awallet.io/</prefix></trade>\n" +
    "      <feemaster>https://app.awallet.io:80/api/claimToken</feemaster>\n" +
    "      <redeem>\n" +
    "        <method name=\"QR\"/>\n" +
    "        <!--\n" +
    "        <method name=\"Aztec\"/>\n" +
    "        <method name=\"Bluetooth\"/>\n" +
    "        -->\n" +
    "      </redeem>\n" +
    "    </feature>\n" +
    "  </features>\n" +
    "  <ordering>\n" +
    "    <order bitmask=\"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\" name=\"default\">\n" +
    "      <byName field=\"locality\"/>\n" +
    "      <byValue field=\"match\"/>\n" +
    "      <byValue field=\"number\"/>\n" +
    "    </order>\n" +
    "    <order bitmask=\"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\" name=\"concise\">\n" +
    "      <byValue field=\"match\"/>\n" +
    "      <byValue field=\"category\"/>\n" +
    "      <byValue field=\"number\"/>\n" +
    "    </order>\n" +
    "  </ordering>\n" +
    "\n" +
    "  <!-- token UI definition can happen here -->\n" +
    "  <fields>\n" +
    "    <!--\n" +
    "    There are 64 matches (1-64), each has up to 16 ticket classes,\n" +
    "    within each class, there are less than 65536 tickets.  A compact\n" +
    "    format identifier would consist of 26 bits:\n" +
    "\n" +
    "    [6] [4] [16]\n" +
    "\n" +
    "    Representing:\n" +
    "\n" +
    "\t    Match ID: 1-64\n" +
    "\t    Class: 1-16\n" +
    "\t    Seat: 0-65536\n" +
    "\n" +
    "    These are represented by 7 hex codes. Therefore 0x40F0481 means\n" +
    "    the final match (64th), class F (highest) ticket number 1153. But\n" +
    "    we didn't end up using this compatct form.\n" +
    "\n" +
    "    Information about a match, like Venue, City, Date, which team\n" +
    "    against which, can all be looked up by MatchID. There are\n" +
    "    advantages and disadvantages in encoding them by a look up table\n" +
    "    or by a bit field.\n" +
    "\n" +
    "    The advantage of storing them as a bit field is that one can\n" +
    "    enquiry the range of it in the market queue server without the\n" +
    "    server kowing the meaning of the bitfields. Furthermore it make\n" +
    "    the android and ios library which accesses the XML file a bit\n" +
    "    easier to write, but at the cost that the ticket issuing\n" +
    "    (authorisation) server is a bit more complicated.\n" +
    "\n" +
    "    For now we decide to use bit-fields.  The fields, together with\n" +
    "    its bitwidth or byte-width are represented in this table:\n" +
    "\n" +
    "    Fields:           City,   Venue,  Date,   TeamA,  TeamB,  Match, Category\n" +
    "    Maximum, 2018:    11,     12,     32,     32,     32,     64,    16\n" +
    "    Maximum, all time:64,     64,     64,     32,     32,     64,    64\n" +
    "    Bitwidth:         6,      6,      6,      5,      5,      6,     6\n" +
    "    Bytewidth:        1,      1,      4,      3,      3,      1,     1,\n" +
    "\n" +
    "    In practise, because this XML file is used in 3 to 4 places\n" +
    "    (authorisation server, ios, android, potentially market-queue),\n" +
    "    Weiwu thought that it helps the developers if we use byte-fields\n" +
    "    instead of bit-fields.\n" +
    "  -->\n" +
    "    <field bitmask=\"00000000000000000000000000000000FF000000000000000000000000000000\" id=\"locality\" type=\"Enumeration\">\n" +
    "      <name lang=\"ru\">город</name>\n" +
    "      <name lang=\"en\">City</name>\n" +
    "      <name lang=\"zh\">城市</name>\n" +
    "      <name lang=\"es\">Ciudad</name>\n" +
    "      <mapping>\n" +
    "        <entity key=\"1\">\n" +
    "          <name lang=\"ru\">Москва́</name>\n" +
    "          <name lang=\"en\">Moscow</name>\n" +
    "          <name lang=\"zh\">莫斯科</name>\n" +
    "          <name lang=\"es\">Moscú</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"2\">\n" +
    "          <name lang=\"ru\">Санкт-Петербу́рг</name>\n" +
    "          <name lang=\"en\">Saint Petersburg</name>\n" +
    "          <name lang=\"zh\">圣彼得堡</name>\n" +
    "          <name lang=\"es\">San Petersburgo</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"3\">\n" +
    "          <name lang=\"ru\">сочи</name>\n" +
    "          <name lang=\"en\">Sochi</name>\n" +
    "          <name lang=\"zh\">索契</name>\n" +
    "          <name lang=\"es\">Sochi</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"4\">\n" +
    "          <name lang=\"ru\">екатеринбург</name>\n" +
    "          <name lang=\"en\">Ekaterinburg</name>\n" +
    "          <name lang=\"zh\">叶卡捷琳堡</name>\n" +
    "          <name lang=\"es\">Ekaterinburg</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"5\">\n" +
    "          <name lang=\"ru\">Саранск</name>\n" +
    "          <name lang=\"en\">Saransk</name>\n" +
    "          <name lang=\"zh\">萨兰斯克</name>\n" +
    "          <name lang=\"es\">Saransk</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"6\">\n" +
    "          <name lang=\"ru\">казань</name>\n" +
    "          <name lang=\"en\">Kazan</name>\n" +
    "          <name lang=\"zh\">喀山</name>\n" +
    "          <name lang=\"es\">Kazan</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"7\">\n" +
    "          <name lang=\"ru\">Нижний Новгород</name>\n" +
    "          <name lang=\"en\">Nizhny Novgorod</name>\n" +
    "          <name lang=\"zh\">下诺夫哥罗德</name>\n" +
    "          <name lang=\"es\">Nizhny Novgorod</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"8\">\n" +
    "          <name lang=\"ru\">Ростов-на-Дону</name>\n" +
    "          <name lang=\"en\">Rostov-on-Don</name>\n" +
    "          <name lang=\"zh\">顿河畔罗斯托夫</name>\n" +
    "          <name lang=\"es\">Rostov-on-Don</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"9\">\n" +
    "          <name lang=\"ru\">Самара</name>\n" +
    "          <name lang=\"en\">Samara</name>\n" +
    "          <name lang=\"zh\">萨马拉</name>\n" +
    "          <name lang=\"es\">Samara</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"10\">\n" +
    "          <name lang=\"ru\">Волгоград</name>\n" +
    "          <name lang=\"en\">Volgograd</name>\n" +
    "          <name lang=\"zh\">伏尔加格勒</name>\n" +
    "          <name lang=\"es\">Volgogrado</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"11\">\n" +
    "          <name lang=\"ru\">Калининград</name>\n" +
    "          <name lang=\"en\">Kaliningrad</name>\n" +
    "          <name lang=\"zh\">加里宁格勒</name>\n" +
    "          <name lang=\"es\">Kaliningrad</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"255\">\n" +
    "          <name lang=\"ru\">Сидней</name>\n" +
    "          <name lang=\"en\">Sydney</name>\n" +
    "          <name lang=\"zh\">悉尼</name>\n" +
    "          <name lang=\"es\">Sídney</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"254\">\n" +
    "          <name lang=\"ru\">Сингапур</name>\n" +
    "          <name lang=\"en\">Singapore</name>\n" +
    "          <name lang=\"zh\">新加坡</name>\n" +
    "          <name lang=\"es\">Singapur</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"253\">\n" +
    "          <name lang=\"en\">Shenzhen</name>\n" +
    "          <name lang=\"zh\">深圳</name>\n" +
    "        </entity>\n" +
    "\t<entity key=\"252\">\n" +
    "          <name lang=\"en\">Beijing</name>\n" +
    "          <name lang=\"zh\">北京</name>\n" +
    "        </entity>\n" +
    "\t<entity key=\"251\">\n" +
    "          <name lang=\"en\">Shanghai</name>\n" +
    "          <name lang=\"zh\">上海</name>\n" +
    "        </entity>\n" +
    "\t<entity key=\"250\">\n" +
    "          <name lang=\"en\">Tokyo</name>\n" +
    "          <name lang=\"zh\">东京</name>\n" +
    "        </entity>      \n" +
    "\t<entity key=\"249\">\n" +
    "          <name lang=\"en\">Seoul</name>\n" +
    "          <name lang=\"zh\">首尔</name>\n" +
    "        </entity>      \n" +
    "\t<entity key=\"248\">\n" +
    "          <name lang=\"en\">Chongqing</name>\n" +
    "          <name lang=\"zh\">重庆</name>\n" +
    "        </entity>\t      \n" +
    "\t<entity key=\"247\">\n" +
    "          <name lang=\"en\">New York</name>\n" +
    "          <name lang=\"zh\">纽约</name>\n" +
    "        </entity>\t      \n" +
    "\t<entity key=\"246\">\n" +
    "          <name lang=\"en\">Melbourne</name>\n" +
    "          <name lang=\"zh\">墨尔本</name>\n" +
    "        </entity>      \n" +
    "\t<entity key=\"245\">\n" +
    "          <name lang=\"en\">Hong Kong</name>\n" +
    "          <name lang=\"zh\">香港</name>\n" +
    "        </entity>     \n" +
    "\t<entity key=\"244\">\n" +
    "          <name lang=\"en\">Chengdu</name>\n" +
    "          <name lang=\"zh\">成都</name>\n" +
    "        </entity>\t      \n" +
    "\t<entity key=\"243\">\n" +
    "          <name lang=\"en\">Kuala Lumpur</name>\n" +
    "          <name lang=\"zh\">吉隆坡</name>\n" +
    "        </entity>\t      \n" +
    "\t<entity key=\"242\">\n" +
    "          <name lang=\"en\">Bangkok</name>\n" +
    "          <name lang=\"zh\">曼谷</name>\n" +
    "        </entity>\t      \n" +
    "\t<entity key=\"241\">\n" +
    "          <name lang=\"en\">San Francisco</name>\n" +
    "          <name lang=\"zh\">三藩市</name>\n" +
    "        </entity>\t      \n" +
    "\t<entity key=\"240\">\n" +
    "          <name lang=\"en\">Las Vegas</name>\n" +
    "          <name lang=\"zh\">拉斯维加斯</name>\n" +
    "        </entity>\t      \n" +
    "\t<entity key=\"239\">\n" +
    "          <name lang=\"en\">London</name>\n" +
    "          <name lang=\"zh\">伦敦</name>\n" +
    "        </entity>\t      \n" +
    "\t<entity key=\"238\">\n" +
    "          <name lang=\"en\">Barcelona</name>\n" +
    "          <name lang=\"zh\">巴塞罗那</name>\n" +
    "        </entity>\t      \n" +
    "\t<entity key=\"237\">\n" +
    "          <name lang=\"en\">Madrid</name>\n" +
    "          <name lang=\"zh\">马德里</name>\n" +
    "        </entity>\n" +
    "\t<entity key=\"236\">\n" +
    "          <name lang=\"en\">Zug</name>\n" +
    "          <name lang=\"zh\">楚格</name>\n" +
    "        </entity>\t      \n" +
    "\t<entity key=\"235\">\n" +
    "          <name lang=\"en\">Paris</name>\n" +
    "          <name lang=\"zh\">巴黎</name>\n" +
    "        </entity>\t      \n" +
    "\t<entity key=\"234\">\n" +
    "          <name lang=\"en\">Dubai</name>\n" +
    "          <name lang=\"zh\">迪拜</name>\n" +
    "        </entity>\n" +
    "\t<entity key=\"233\">\n" +
    "          <name lang=\"en\">TBC</name>\n" +
    "          <name lang=\"zh\">待定</name>\n" +
    "        </entity>      \n" +
    "      </mapping>\n" +
    "    </field>\n" +
    "    <field bitmask=\"0000000000000000000000000000000000FF0000000000000000000000000000\" id=\"venue\" type=\"Enumeration\">\n" +
    "      <name lang=\"ru\">место встречи</name>\n" +
    "      <name lang=\"en\">Venue</name>\n" +
    "      <name lang=\"zh\">场馆</name>\n" +
    "      <name lang=\"es\">Lugar</name>\n" +
    "      <mapping>\n" +
    "        <entity key=\"1\">\n" +
    "          <name lang=\"ru\">Стадион Калининград</name>\n" +
    "          <name lang=\"en\">Kaliningrad Stadium</name>\n" +
    "          <name lang=\"zh\">加里宁格勒体育场</name>\n" +
    "          <name lang=\"es\">Estadio de Kaliningrado</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"2\">\n" +
    "          <name lang=\"ru\">Екатеринбург Арена</name>\n" +
    "          <name lang=\"en\">Volgograd Arena</name>\n" +
    "          <name lang=\"zh\">伏尔加格勒体育场</name>\n" +
    "          <name lang=\"es\">Volgogrado Arena</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"3\">\n" +
    "          <name lang=\"ru\">Казань Арена</name>\n" +
    "          <name lang=\"en\">Ekaterinburg Arena</name>\n" +
    "          <name lang=\"zh\">加里宁格勒体育场</name>\n" +
    "          <name lang=\"es\">Ekaterimburgo Arena</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"4\">\n" +
    "          <name lang=\"ru\">Мордовия Арена</name>\n" +
    "          <name lang=\"en\">Fisht Stadium</name>\n" +
    "          <name lang=\"zh\">费什体育场</name>\n" +
    "          <name lang=\"es\">Estadio Fisht</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"5\">\n" +
    "          <name lang=\"ru\">Ростов Арена</name>\n" +
    "          <name lang=\"en\">Kazan Arena</name>\n" +
    "          <name lang=\"zh\">喀山体育场</name>\n" +
    "          <name lang=\"es\">Kazan Arena</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"6\">\n" +
    "          <name lang=\"ru\">Самара Арена</name>\n" +
    "          <name lang=\"en\">Nizhny Novgorod Stadium</name>\n" +
    "          <name lang=\"zh\">下诺夫哥罗德体育场</name>\n" +
    "          <name lang=\"es\">Estadio de Nizhni Novgorod</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"7\">\n" +
    "          <name lang=\"ru\">Стадион Калининград</name>\n" +
    "          <name lang=\"en\">Luzhniki Stadium</name>\n" +
    "          <name lang=\"zh\">卢日尼基体育场</name>\n" +
    "          <name lang=\"es\">Estadio Luzhniki</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"8\">\n" +
    "          <name lang=\"ru\">Стадион Лужники</name>\n" +
    "          <name lang=\"en\">Samara Arena</name>\n" +
    "          <name lang=\"zh\">萨马拉体育场</name>\n" +
    "          <name lang=\"es\">Samara Arena</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"9\">\n" +
    "          <name lang=\"ru\">Стадион Нижний Новгород</name>\n" +
    "          <name lang=\"en\">Rostov Arena</name>\n" +
    "          <name lang=\"zh\">罗斯托夫体育场</name>\n" +
    "          <name lang=\"es\">Rostov Arena</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"10\">\n" +
    "          <name lang=\"ru\">Стадион Спартак</name>\n" +
    "          <name lang=\"en\">Spartak Stadium</name>\n" +
    "          <name lang=\"zh\">斯巴达克体育场</name>\n" +
    "          <name lang=\"es\">Estadio del Spartak</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"11\">\n" +
    "          <name lang=\"ru\">Стадион Санкт-Петербург</name>\n" +
    "          <name lang=\"en\">Saint Petersburg Stadium</name>\n" +
    "          <name lang=\"zh\">圣彼得堡体育场</name>\n" +
    "          <name lang=\"es\">Estadio de San Petersburgo</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"12\">\n" +
    "          <name lang=\"ru\">Стадион Фишт</name>\n" +
    "          <name lang=\"en\">Mordovia Arena</name>\n" +
    "          <name lang=\"zh\">莫多维亚体育场</name>\n" +
    "          <name lang=\"es\">Mordovia Arena</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"255\">\n" +
    "\t  <name lang=\"ru\">UNSW Michael Crouch Innovation Center</name>\t\n" +
    "          <name lang=\"en\">UNSW Michael Crouch Innovation Center</name>\n" +
    "          <name lang=\"zh\">新南威尔大学Michael Crouch创新中心</name>\n" +
    "          <name lang=\"es\">Centro de Innovación de Michael Crouch UNSW</name>\n" +
    "        </entity>\n" +
    "\t  <entity key=\"254\">\n" +
    "\t  <name lang=\"ru\">FOUR SEASONS HOTEL SHENZHEN</name>\t  \n" +
    "          <name lang=\"en\">FOUR SEASONS HOTEL SHENZHEN</name>\n" +
    "          <name lang=\"zh\">深圳四季酒店</name>\n" +
    "          <name lang=\"es\">FOUR SEASONS HOTEL SHENZHEN</name>\n" +
    "        </entity>\n" +
    "\t  <entity key=\"253\">\n" +
    "\t  <name lang=\"ru\">Paypal Innovation Lab</name>\t\t  \n" +
    "          <name lang=\"en\">Paypal Innovation Lab</name>\n" +
    "          <name lang=\"zh\">Paypal Innovation Lab</name>\n" +
    "          <name lang=\"es\">Paypal Innovation Lab</name>\n" +
    "        </entity>\n" +
    "\t  <entity key=\"252\">\n" +
    "\t  <name lang=\"ru\">The Centrepoint</name>\t  \n" +
    "          <name lang=\"en\">The Centrepoint</name>\n" +
    "          <name lang=\"zh\">The Centrepoint</name>\n" +
    "          <name lang=\"es\">The Centrepoint</name>\n" +
    "        </entity>      \n" +
    "\t  <entity key=\"251\">\n" +
    "\t  <name lang=\"ru\">The Centrepoint</name>\t  \n" +
    "          <name lang=\"en\">TBC</name>\n" +
    "          <name lang=\"zh\">待定</name>\n" +
    "          <name lang=\"es\">Por determinar</name>\n" +
    "        </entity>      \n" +
    "\t  <entity key=\"250\">\n" +
    "\t  <name lang=\"ru\">thebridge</name>\t  \n" +
    "          <name lang=\"en\">thebridge</name>\n" +
    "          <name lang=\"zh\">thebridge</name>\n" +
    "          <name lang=\"es\">thebridge</name>\n" +
    "        </entity>      \n" +
    "\t  <entity key=\"249\">\n" +
    "\t  <name lang=\"ru\">BASH</name>\t  \n" +
    "          <name lang=\"en\">BASH</name>\n" +
    "          <name lang=\"zh\">BASH</name>\n" +
    "          <name lang=\"es\">BASH</name>\n" +
    "        </entity>      \n" +
    "\t  <entity key=\"248\">\n" +
    "\t  <name lang=\"ru\">Spacemob</name>\t  \n" +
    "          <name lang=\"en\">Spacemob</name>\n" +
    "          <name lang=\"zh\">Spacemob</name>\n" +
    "          <name lang=\"es\">Spacemob</name>\n" +
    "        </entity>      \n" +
    "\t  <entity key=\"247\">\n" +
    "\t  <name lang=\"ru\">32 Carpenter Street</name>\n" +
    "          <name lang=\"en\">32 Carpenter Street</name>\n" +
    "          <name lang=\"zh\">32 Carpenter Street</name>\n" +
    "          <name lang=\"es\">32 Carpenter Street</name>\n" +
    "        </entity>\n" +
    "\t  <entity key=\"246\">\n" +
    "\t  <name lang=\"ru\">Block 71</name>\t  \n" +
    "          <name lang=\"en\">Block 71</name>\n" +
    "          <name lang=\"zh\">Block 71</name>\n" +
    "          <name lang=\"es\">Block 71</name>\n" +
    "        </entity>\n" +
    "\t  <entity key=\"245\">\n" +
    "\t  <name lang=\"ru\">Microsoft Singapore</name>\n" +
    "          <name lang=\"en\">Microsoft Singapore</name>\n" +
    "          <name lang=\"zh\">Microsoft Singapore</name>\n" +
    "          <name lang=\"es\">Microsoft Singapore</name>\n" +
    "        </entity>      \n" +
    "\t  <entity key=\"243\">\n" +
    "\t  <name lang=\"ru\">Google Singapore</name>\t  \n" +
    "          <name lang=\"en\">Google Singapore</name>\n" +
    "          <name lang=\"zh\">Google Singapore</name>\n" +
    "          <name lang=\"es\">Google Singapore</name>\n" +
    "        </entity>\t      \n" +
    "\t  <entity key=\"242\">\n" +
    "\t  <name lang=\"ru\">The Blockchain Hub</name>\t  \n" +
    "          <name lang=\"en\">The Blockchain Hub</name>\n" +
    "          <name lang=\"zh\">The Blockchain Hub</name>\n" +
    "          <name lang=\"es\">The Blockchain Hub</name>\n" +
    "        </entity>\t      \n" +
    "\t  <entity key=\"241\">\n" +
    "\t  <name lang=\"ru\">BitTemple</name>\t  \n" +
    "          <name lang=\"en\">BitTemple</name>\n" +
    "          <name lang=\"zh\">BitTemple</name>\n" +
    "          <name lang=\"es\">BitTemple</name>\n" +
    "        </entity>\n" +
    "\t  <entity key=\"240\">\n" +
    "\t  <name lang=\"ru\">ADD BLOCKCHAIN STUDIO</name>\t  \n" +
    "          <name lang=\"en\">ADD BLOCKCHAIN STUDIO</name>\n" +
    "          <name lang=\"zh\">ADD BLOCKCHAIN STUDIO</name>\n" +
    "          <name lang=\"es\">ADD BLOCKCHAIN STUDIO</name>\n" +
    "        </entity>\n" +
    "\t  <entity key=\"239\">\n" +
    "\t  <name lang=\"ru\">Rosewood Beijing</name>\t  \n" +
    "          <name lang=\"en\">Rosewood Beijing</name>\n" +
    "          <name lang=\"zh\">北京瑰丽酒店</name>\n" +
    "          <name lang=\"es\">Rosewood Beijing</name>\n" +
    "        </entity>\n" +
    "\t  <entity key=\"238\">\n" +
    "\t  <name lang=\"ru\">Stratum</name>\n" +
    "          <name lang=\"en\">Stratum</name>\n" +
    "          <name lang=\"zh\">Stratum</name>\n" +
    "          <name lang=\"es\">Stratum</name>\n" +
    "        </entity>       \n" +
    "      </mapping>\n" +
    "    </field>\n" +
    "    <field bitmask=\"000000000000000000000000000000000000FFFFFFFF00000000000000000000\" id=\"time\" type=\"BinaryTime\">\n" +
    "      <name lang=\"ru\">время</name>\n" +
    "      <name lang=\"en\">Time</name>\n" +
    "      <name lang=\"zh\">时间</name>\n" +
    "      <name lang=\"es\">Tiempo</name>\n" +
    "    </field>\n" +
    "    <field bitmask=\"00000000000000000000000000000000000000000000FFFFFF00000000000000\" id=\"countryA\" type=\"IA5String\">\n" +
    "      <!-- Intentionally avoid using countryName\n" +
    "\t   (SYNTAX 1.3.6.1.4.1.1466.115.121.1.11) per RFC 4519\n" +
    "           CountryName is two-characters long, not 3-characters.\n" +
    "\t   -->\n" +
    "      <name lang=\"en\">Team A</name>\n" +
    "      <name lang=\"zh\">甲队</name>\n" +
    "      <name lang=\"es\">Equipo A</name>\n" +
    "    </field>\n" +
    "    <field bitmask=\"00000000000000000000000000000000000000000000000000FFFFFF00000000\" id=\"countryB\" type=\"IA5String\">\n" +
    "      <name lang=\"en\">Team B</name>\n" +
    "      <name lang=\"zh\">乙队</name>\n" +
    "      <name lang=\"es\">Equipo B</name>\n" +
    "    </field>\n" +
    "    <field bitmask=\"00000000000000000000000000000000000000000000000000000000FF000000\" id=\"match\" type=\"Integer\">\n" +
    "      <name lang=\"en\">Match</name>\n" +
    "      <name lang=\"zh\">场次</name>\n" +
    "      <name lang=\"es\">Evento</name>\n" +
    "    </field>\n" +
    "    <field bitmask=\"0000000000000000000000000000000000000000000000000000000000FF0000\" id=\"category\" type=\"Enumeration\">\n" +
    "      <name lang=\"en\">Cat</name>\n" +
    "      <name lang=\"zh\">等级</name>\n" +
    "      <name lang=\"es\">Cat</name>\n" +
    "      <mapping>\n" +
    "        <entity key=\"1\">\n" +
    "\t  <name lang=\"ru\">Category 1</name>\n" +
    "          <name lang=\"en\">Category 1</name>\n" +
    "          <name lang=\"zh\">一类票</name>\n" +
    "\t  <name lang=\"es\">Category 1</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"2\">\n" +
    "\t  <name lang=\"ru\">Category 2</name>\n" +
    "          <name lang=\"en\">Category 2</name>\n" +
    "          <name lang=\"zh\">二类票</name>\n" +
    "\t  <name lang=\"es\">Category 2</name>\n" +
    "        </entity>\n" +
    "\t  <entity key=\"3\">\n" +
    "\t  <name lang=\"ru\">Category 3</name>\n" +
    "          <name lang=\"en\">Category 3</name>\n" +
    "          <name lang=\"zh\">三类票</name>\n" +
    "\t  <name lang=\"es\">Category 3</name> \t  \n" +
    "        </entity>\n" +
    "\t       <entity key=\"4\">\n" +
    "\t  <name lang=\"ru\">Category 4</name>\t       \n" +
    "          <name lang=\"en\">Category 4</name>\n" +
    "          <name lang=\"zh\">四类票</name>\n" +
    "\t  <name lang=\"es\">Category 4</name>\t       \n" +
    "        </entity>\n" +
    "        <entity key=\"5\">\n" +
    "\t  <name lang=\"ru\">Match Club</name>\t\n" +
    "          <name lang=\"en\">Match Club</name>\n" +
    "          <name lang=\"zh\">俱乐部坐席</name>\n" +
    "\t  <name lang=\"es\">Match Club</name>\t\n" +
    "        </entity>\n" +
    "\t<entity key=\"6\">\n" +
    "\t\t<name lang=\"ru\">Match House Premier</name>\n" +
    "\t\t<name lang=\"en\">Match House Premier</name>\n" +
    "\t\t<name lang=\"zh\">比赛之家坐席</name>\n" +
    "\t\t<name lang=\"es\">Match House Premier</name>\n" +
    "\t</entity>\n" +
    "\t       <entity key=\"7\">\n" +
    "          <name lang=\"ru\">MATCH PAVILION</name>\n" +
    "          <name lang=\"en\">MATCH PAVILION</name>\n" +
    "          <name lang=\"zh\">款待大厅坐席</name>\n" +
    "       \t  <name lang=\"es\">MATCH PAVILION</name>\n" +
    "        </entity>\n" +
    "\t       <entity key=\"8\">\n" +
    "\t  <name lang=\"ru\">MATCH BUSINESS SEAT</name>\t       \n" +
    "          <name lang=\"en\">MATCH BUSINESS SEAT</name>\n" +
    "          <name lang=\"zh\">商务坐席</name>\n" +
    "\t  <name lang=\"es\">MATCH BUSINESS SEAT</name>\t       \n" +
    "        </entity>\n" +
    "\t       <entity key=\"9\">\n" +
    "\t  <name lang=\"ru\">MATCH SHARED SUITE</name>\n" +
    "          <name lang=\"en\">MATCH SHARED SUITE</name>\n" +
    "          <name lang=\"zh\">公共包厢</name>\n" +
    "\t  <name lang=\"es\">MATCH SHARED SUITE</name>\t       \n" +
    "        </entity>\n" +
    "\t       <entity key=\"10\">\n" +
    "          <name lang=\"ru\">TSARSKY LOUNGE</name>\n" +
    "          <name lang=\"en\">TSARSKY LOUNGE</name>\n" +
    "          <name lang=\"zh\">特拉斯基豪华包厢</name>\n" +
    "\t  <name lang=\"es\">TSARSKY LOUNGE</name>\t       \n" +
    "        </entity>\n" +
    "\t         <entity key=\"11\">\n" +
    "\t  <name lang=\"ru\"> MATCH PRIVATE SUITE</name>\t\t \n" +
    "          <name lang=\"en\"> MATCH PRIVATE SUITE</name>\n" +
    "          <name lang=\"zh\">私人包厢</name>\n" +
    "\t  <name lang=\"es\"> MATCH PRIVATE SUITE</name>\n" +
    "        </entity>    \n" +
    "  \n" +
    "        <entity key=\"255\">\n" +
    "\t  <name lang=\"ru\">Singapore Blockchain Event</name>\n" +
    "          <name lang=\"en\">Singapore Blockchain Event</name>\n" +
    "          <name lang=\"zh\">新加坡区块链活动</name>\n" +
    "\t  <name lang=\"es\">Singapore Blockchain Event</name>\n" +
    "        </entity>\n" +
    "\t<entity key=\"254\">\n" +
    "\t  <name lang=\"ru\">Singapore Blockchain Event</name>\t\n" +
    "          <name lang=\"en\">TECHNOLOGY RADAR SUMMIT 2018</name>\n" +
    "          <name lang=\"zh\">技术雷达峰会2018</name>\n" +
    "\t  <name lang=\"es\">Singapore Blockchain Event</name>\t\n" +
    "        </entity>\n" +
    "\t       <entity key=\"253\">\n" +
    "          <name lang=\"ru\">Sydney Blockchain Event</name>\n" +
    "          <name lang=\"en\">Sydney Blockchain Event</name>\n" +
    "          <name lang=\"zh\">悉尼区块链活动</name>\n" +
    "\t  <name lang=\"es\">Sydney Blockchain Event</name>\t       \n" +
    "        </entity>\n" +
    "\t       <entity key=\"252\">\n" +
    "          <name lang=\"ru\">Beijing Blockchain Event</name>\n" +
    "          <name lang=\"en\">Beijing Blockchain Event</name>\n" +
    "          <name lang=\"zh\">北京区块链活动</name>\n" +
    "          <name lang=\"es\">Beijing Blockchain Event</name>\n" +
    "        </entity>\n" +
    "\t       <entity key=\"251\">\n" +
    "          <name lang=\"ru\">Shanghai Blockchain Event</name>\n" +
    "          <name lang=\"en\">Shanghai Blockchain Event</name>\n" +
    "          <name lang=\"zh\">上海区块链活动</name>\n" +
    "          <name lang=\"es\">Shanghai Blockchain Event</name>\n" +
    "        </entity>\n" +
    "\t       <entity key=\"250\">\n" +
    "          <name lang=\"ru\">Tokyo Blockchain Event</name>\n" +
    "          <name lang=\"en\">Tokyo Blockchain Event</name>\n" +
    "          <name lang=\"zh\">东京区块链活动</name>\n" +
    "          <name lang=\"es\">Tokyo Blockchain Event</name>\n" +
    "        </entity>\n" +
    "\t       <entity key=\"249\">\n" +
    "\t  <name lang=\"ru\">Blockchain Event</name>\n" +
    "          <name lang=\"en\">Blockchain Event</name>\n" +
    "          <name lang=\"zh\">区块链活动</name>\n" +
    "\t  <name lang=\"es\">Blockchain Event</name>\n" +
    "        </entity>\n" +
    "\t       <entity key=\"248\">\n" +
    "          <name lang=\"ru\">Other Events</name>\n" +
    "          <name lang=\"en\">Other Events</name>\n" +
    "          <name lang=\"zh\">其他活动</name>\n" +
    "\t  <name lang=\"es\">Other Events</name>\t       \n" +
    "        </entity>\n" +
    "\t       <entity key=\"247\">\n" +
    "          <name lang=\"ru\">Seoul Blockchain Event</name>\n" +
    "          <name lang=\"en\">Seoul Blockchain Event</name>\n" +
    "          <name lang=\"zh\">首尔区块链活动</name>\n" +
    "          <name lang=\"es\">Seoul Blockchain Event</name>\n" +
    "        </entity>\n" +
    "\t       <entity key=\"246\">\n" +
    "          <name lang=\"ru\">Bangkok Blockchain Event</name>\n" +
    "          <name lang=\"en\">Bangkok Blockchain Event</name>\n" +
    "          <name lang=\"zh\">曼谷区块链活动</name>\n" +
    "          <name lang=\"es\">Bangkok Blockchain Event</name>\n" +
    "        </entity>\n" +
    "\t       <entity key=\"245\">\n" +
    "          <name lang=\"ru\">AlphaWallet Event</name>\n" +
    "          <name lang=\"en\">AlphaWallet Event</name>\n" +
    "          <name lang=\"zh\">AlphaWallet活动</name>\n" +
    "          <name lang=\"es\">AlphaWallet Event</name>\n" +
    "        </entity>\n" +
    "\t       <entity key=\"254\">\n" +
    "\t  <name lang=\"ru\">Stormbird Event</name>\t       \n" +
    "          <name lang=\"en\">Stormbird Event</name>\n" +
    "          <name lang=\"zh\">Stormbird活动</name>\n" +
    "\t  <name lang=\"es\">Stormbird Event</name>\t       \n" +
    "        </entity>\n" +
    "\t       <entity key=\"253\">\n" +
    "          <name lang=\"ru\">UNITY VENTURES Event</name>\n" +
    "          <name lang=\"en\">UNITY VENTURES Event</name>\n" +
    "          <name lang=\"zh\">九合创投活动</name>\n" +
    "          <name lang=\"es\">UNITY VENTURES Event</name>\n" +
    "        </entity>\n" +
    "\t       <entity key=\"252\">\n" +
    "\t  <name lang=\"ru\">Max's Event</name>\t       \n" +
    "          <name lang=\"en\">Max's Event</name>\n" +
    "          <name lang=\"zh\">Max的活动</name>\n" +
    "          <name lang=\"es\">Max's Event</name>\n" +
    "        </entity>\n" +
    "\t       <entity key=\"251\">\n" +
    "          <name lang=\"ru\">Chongqing Blockchain Event</name>\n" +
    "          <name lang=\"en\">Chongqing Blockchain Event</name>\n" +
    "          <name lang=\"zh\">重庆区块链活动</name>\n" +
    "          <name lang=\"es\">Chongqing Blockchain Event</name>\n" +
    "        </entity>\n" +
    "\t       <entity key=\"250\">\n" +
    "          <name lang=\"ru\">Dubai Blockchain Event</name>\n" +
    "          <name lang=\"en\">Dubai Blockchain Event</name>\n" +
    "          <name lang=\"zh\">迪拜区块链活动</name>\n" +
    "\t  <name lang=\"es\">Dubai Blockchain Event</name>\t       \n" +
    "        </entity>\n" +
    "\t       <entity key=\"249\">\n" +
    "          <name lang=\"ru\">Silicon Valley Blockchain Event</name>\n" +
    "          <name lang=\"en\">Silicon Valley Blockchain Event</name>\n" +
    "          <name lang=\"zh\">硅谷区块链活动</name>\n" +
    "          <name lang=\"es\">Silicon Valley Blockchain Event</name>\n" +
    "        </entity>\n" +
    "\t       <entity key=\"248\">\n" +
    "          <name lang=\"ru\">Melbourne Blockchain Event</name>\n" +
    "          <name lang=\"en\">Melbourne Blockchain Event</name>\n" +
    "          <name lang=\"zh\">墨尔本区块链活动</name>\n" +
    "\t  <name lang=\"es\">Melbourne Blockchain Event</name>\n" +
    "        </entity>\n" +
    "\t       <entity key=\"247\">\n" +
    "          <name lang=\"ru\">General Event</name>\n" +
    "          <name lang=\"en\">General Event</name>\n" +
    "          <name lang=\"zh\">通用活动</name>\n" +
    "\t  <name lang=\"es\">General Event</name>\t       \n" +
    "        </entity>\n" +
    "      \n" +
    "      </mapping>\n" +
    "    </field>\n" +
    "    <field bitmask=\"000000000000000000000000000000000000000000000000000000000000FFFF\" id=\"numero\" type=\"Integer\">\n" +
    "      <name>№</name>\n" +
    "    </field>\n" +
    "  </fields>\n" +
    "</asset>\n"
}
