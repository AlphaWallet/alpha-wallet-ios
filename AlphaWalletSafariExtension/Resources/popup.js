'use strict';

var options = optionsByDefault;
const checkbox = document.getElementById('overridingEnabledCheckbox');
const checkbox_2 = document.getElementById('overridingEnabledCheckboxWC');

browser.storage.local.get('options', (data) => {
    Object.assign(options, data.options);

    checkbox.checked = Boolean(options.enableEip681UrlsOverriding);
    checkbox_2.checked = Boolean(options.enableWCUrlsOverriding);
});

checkbox.addEventListener('change', (event) => {
    options.enableEip681UrlsOverriding = event.target.checked;
    browser.storage.local.set({options});
});

checkbox_2.addEventListener('change', (event) => {
    options.enableWCUrlsOverriding = event.target.checked;
    browser.storage.local.set({options});
});
