
function restoreOverridenURLs(elements) {
    for (let i = 0; i < elements.length; i++) {
        elements[i].element.href = elements[i].href;
    }
}

function retrieveAllURLs(document, options) {
    const alpwaWalletPrefix = options.alphaWalletPrefix;
    const mapper = new hrefMapper(options)
    let tags = options.elementsForOverride.map((tag) => {
        return Array.from(document.getElementsByTagName(tag));
    })
    .flat()
    .filter((each) => { return (typeof each.href != 'undefined') })

    let overridenElements = new Array();

    tags.forEach((each) => {
        let updatedHref = mapper.overrideHref(each.href);
        if (typeof updatedHref != 'undefined') {
            overridenElements.push({
                href: each.href,
                overridenHref: updatedHref,
                element: each
            });

            each.href = updatedHref;
        }
    });

    return overridenElements;
}
