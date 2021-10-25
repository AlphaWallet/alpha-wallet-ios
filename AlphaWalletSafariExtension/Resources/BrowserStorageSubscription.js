function BrowserStorageSubscription(callback) {
    browser.storage.local.get('options').then((data) => {
        var options;
        if (isEmpty(data) || (typeof data.options == 'undefined') || typeof data.options != 'object' || typeof data.options.enableEip681UrlsOverriding != 'boolean'|| typeof data.options.enableWCUrlsOverriding != 'boolean') {
            browser.storage.local.set({optionsByDefault})
            options = optionsByDefault;
        } else {
            options = data.options;
        }
        return options;
    }).then((options) => {
        callback(options);
    })

    browser.storage.local.onChanged.addListener((changes) => {
        if (changes.options?.newValue) {
            let options = changes.options.newValue
            callback(options);
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
