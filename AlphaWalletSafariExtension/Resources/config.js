'use strict';

var optionsByDefault = {
    enableEip681UrlsOverriding: true,
    enableWCUrlsOverriding: true,
    alphaWalletPrefix: "https://aw.app/",
    elementsForOverride: ["a", "link"]
}

function hrefMapper(options) {
    const alpwaWalletPrefix = options.alphaWalletPrefix;
    let defaultMapper = function(element) {
        return alpwaWalletPrefix + element;
    }

    this.handlers = [
        {validate: isValidEip681, mapper: defaultMapper},
        {validate: isValidWalletConnect, mapper: defaultMapper}
    ];

    this.overrideHref = function(str) {
        let elements = this.handlers.map(function(element) {
            if (element.validate(options, str)) {
                return element.mapper(str);
            } else {
                return undefined;
            }
        })
        .filter(each => { return (each != undefined) });

        if(elements.isEmpty) {
            return undefined;
        } else {
            return elements[0];
        }
    }
}

function isValidEip681(options, str) {
    return options.enableEip681UrlsOverriding && str.startsWith("ethereum:");
}

function isValidWalletConnect(options, str) {
    return options.enableWCUrlsOverriding && str.startsWith("wc:");
}
