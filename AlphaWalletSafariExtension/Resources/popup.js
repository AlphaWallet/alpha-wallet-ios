'use strict';

var options = optionsByDefault;
const checkbox = document.getElementById('overridingEnabledCheckbox');
browser.storage.local.get('options', (data) => {
    Object.assign(options, data.options);
    checkbox.checked = Boolean(options.enableEip681UrlsOverriding);
});

// Immediately persist options changes
checkbox.addEventListener('change', (event) => {
    options.enableEip681UrlsOverriding = event.target.checked;
    browser.storage.local.set({options});
});
