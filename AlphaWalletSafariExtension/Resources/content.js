'use strict';
const overridenElements = new Map();

function runOnStart() {
    function applyURLsOverriding(options, url) {
        let elements = overridenElements.get(url);
        if (typeof elements != 'undefined') {
            restoreOverridenURLs(elements)
        }
        
        if (options.enableEip681UrlsOverriding) {
            overridenElements.set(url, retrieveAllURLs(document, options));
        }
    }
    browser.storage.local.get('options').then((data) => {
        var options;
        if (isEmpty(data) || (typeof data.options == 'undefined') || typeof data.options != 'object' || typeof data.options.enableEip681UrlsOverriding != 'boolean') {
            browser.storage.local.set({optionsByDefault})
            options = optionsByDefault;
        } else {
            options = data.options;
        }
        return options;
    }).then((options) => {
        const url = document.URL;
        applyURLsOverriding(options, url)
    })

    browser.storage.local.onChanged.addListener((changes) => {
        if (typeof changes.options?.newValue?.debug == 'boolean') {
            let options = changes.options.newValue
            const url = document.URL;
            applyURLsOverriding(options, url)
        }
    });
}

function isEmpty(obj) {
  for(var prop in obj) {
    if(Object.prototype.hasOwnProperty.call(obj, prop)) {
      return false;
    }
  }

  return JSON.stringify(obj) === JSON.stringify({});
}

if(document.readyState !== 'loading') {
    runOnStart();
} else {
    document.addEventListener('DOMContentLoaded', function () {
        runOnStart()
    });
}

function restoreOverridenURLs(elements) {
    for (let i = 0; i < elements.length; i++) {
        elements[i].element.href = elements[i].href;
    }
}

function retrieveAllURLs(document, options) {
    const alpwaWalletPrefix = options.alphaWalletPrefix;
    let tags = options.elementsForOverride.map((tag) => {
        return Array.from(document.getElementsByTagName(tag));
    })
    .flat()
    .filter((each) => { return (typeof each.href != 'undefined' && isValidEip681(each.href)) })

    let overridenElements = new Array();

    tags.forEach((each) => {
        let updatedHref = alpwaWalletPrefix + each.href;
        overridenElements.push({
            href: each.href,
            overridenHref: updatedHref,
            element: each
        });

        each.href = updatedHref;
    });

    return overridenElements;
}

function isValidEip681(str) {
    return str.startsWith("ethereum:");
}
