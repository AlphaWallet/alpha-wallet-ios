const {danger, warn} = require('danger')

if (danger.github) {
} else {
    warnHTMLLocalizationMissing()
    warnStringLocalizationMissing()
    warnClosureStronglyCapturesSelf()
    failUsingNSLocalizedStringWithoutR()
    failIfRemoveAnyRealmSchemaMigrationBlock()
    checkForSpacesInOtherwiseEmptyLines()
}

function warnHTMLLocalizationMissing() {
    const changedHtmlFiles = danger.git.modified_files.filter(f => f.includes("/en.lproj/") && f.includes(".html"))
    changedHtmlFiles.forEach(each =>
        warn("HTML changed. Double check that you have changed it for all languages, or will do so in another PR: " + each)
    )
}

function warnStringLocalizationMissing() {
    const includesLocalizationChanges = danger.git.modified_files.filter(f => f == "AlphaWallet/Localization/en.lproj/Localizable.strings").length > 0
    if (includesLocalizationChanges) {
        warn("Localization file changed. Double check that you have changed it for all languages, or will do so in another PR")
    }
}

function warnClosureStronglyCapturesSelf() {
    modifiedSwiftFiles().forEach(each => {
        danger.git.diffForFile(each).then(diff => {
            if (diff.added.includes("self.")) {
                warn(each + ": added `self.`. Double check if closure strongly captures `self`.")
            }
        })
    })
}

function failUsingNSLocalizedStringWithoutR() {
    modifiedSwiftFiles().forEach(each => {
        danger.git.diffForFile(each).then(diff => {
            if (diff.added.includes("NSLocalizedString")) {
                fail(each + ": added `NSLocalizedString`. Should use `R.string.localizable` instead.")
            }
        })
    })
}

function failIfRemoveAnyRealmSchemaMigrationBlock() {
    modifiedSwiftFiles().forEach(each => {
        danger.git.diffForFile(each).then(diff => {
            if (diff.removed.includes("if oldSchemaVersion <")) {
                fail(each + ": removed `if oldSchemaVersion <`. Migration blocks for previous versions should never be removed.")
            }
        })
    })
}

function checkForSpacesInOtherwiseEmptyLines() {
    modifiedSwiftFiles().forEach(each => {
        danger.git.diffForFile(each).then(diff => {
            if (diff.added.includes("    \n")) {
                fail(each + ": leading spaces for otherwise empty lines should be removed.")
            }
        })
    })
}


function modifiedSwiftFiles() {
    return danger.git.modified_files.filter(f => f.includes(".swift"))
}

function intersect(a, b) {
    var t;
    if (b.length > a.length) t = b, b = a, a = t; // indexOf to loop over shorter
    return a.filter(function (e) {
        return b.indexOf(e) > -1;
    });
}
