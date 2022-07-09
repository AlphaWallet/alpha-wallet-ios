Deep link-based wallet API
===
The API provides a way for mobile apps to communicate with AlphaWallet via deep links.

Calls
---
Parameters are passed as query strings. There are 2 endpoints:

- /wallet/v1/connect
    - Parameters:
        - `redirecturl` — refer below
        - `metadata` — refer below
    - Result
        - Success
            - call=connect
            - address=<current Ethereum address>
        - Failure
            - call=connect
- /wallet/v1/signpersonalmessage
    - Parameters
        - `redirecturl` — refer below
        - `metadata` — refer below
        - `address` — address for key to sign with (wallet will check this matches current Ethereum address)
        - `message` — In hex string representation
    - Result
        - Success
            - call=signpersonalmessage
            - signature=signature
        - Failure
            - call=signpersonalmessage
            - (we provide an error message/code for the current version)

Common parameters:

- `redirecturl` — the callback URL to open to pass results back
- `metadata` - app metadata, must be JSON containing "name" and "iconurl" and an optional: "appurl"
    - name — name of the app
    - iconurl — URL pointing to an icon for the app. png, jpeg
    - appurl - optional. URL pointing to a webpage with information about the app

Example deep links the client apps should form:

- Connect — https://aw.app/wallet/v1/connect?redirecturl=https%3A%2F%2Fmyapp.com&metadata=%7B%22name%22%3A%22Some+app%22%2C%22iconurl%22%3A%22https%3A%2F%2Fimg.icons8.com%2Fnolan%2F344%2Fethereum.png%22%7D
- Sign personal message — https://aw.app/wallet/v1/signpersonalmessage?redirecturl=https%3A%2F%2Fmyapp.com&metadata=%7B%22name%22%3A%22Some+app%22%2C%22iconurl%22%3A%22https%3A%2F%2Fimg.icons8.com%2Fnolan%2F344%2Fethereum.png%22%2C%22appurl%22%3A%22https%3A%2F%2Fgoogle.com%22%7D&address=0xbbce83173d5c1D122AE64856b4Af0D5AE07Fa362&message=0x48656c6c6f20416c7068612057616c6c6574

Note that whitespace (`0x20`) can be encoded as `+` or `%20`

## Results

Results will be passed by opening the `redirecturl` which the client app should have been configured to handle, appending the results, eg.

- https://myapp.com?call=connect&address=0x007bEe82BDd9e866b2bd114780a47f2261C684E3

So the `redirecturl` should be a deep link the client mobile apps are configured to handle
