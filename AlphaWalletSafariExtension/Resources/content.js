'use strict';
const overridenElements = new Map();
var subscription;

function runOnStart() {
    function applyURLsOverriding(options, url) {
        let elements = overridenElements.get(url);
        if (typeof elements != 'undefined') {
            restoreOverridenURLs(elements)
        }
        
        overridenElements.set(url, retrieveAllURLs(document, options));
    }

    subscription = new BrowserStorageSubscription(function(options) {
        const url = document.URL;
        applyURLsOverriding(options, url);
    })
}

if(document.readyState !== 'loading') {
    runOnStart();
} else {
    document.addEventListener('DOMContentLoaded', function() {
        runOnStart()
    });
}
