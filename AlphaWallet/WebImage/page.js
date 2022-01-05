    function loadImageSucceed(url) {
        $("img.sized").imageScale({rescaleOnResize: true});
        window.webkit.messageHandlers.WebImage.postMessage(`loadImageSucceed aw_separator ${url}`)
    }

    function loadImageFailure(url) {
        window.webkit.messageHandlers.WebImage.postMessage(`loadImageFailure aw_separator ${url}`)
    }

    $(document).ready(function() {
        window.webkit.messageHandlers.WebImage.postMessage("pageDidLoad")
    });

    function setImage(url) {
        $('img.sized').attr('src', url);
    }

    /*
    $.fn.cacheImages.defaults.debug = true;
    $.fn.cacheImages.defaults.defaultImage = window.location.origin + window.location.pathname.substr(0, window.location.pathname.length - 10) + '/assets/no-image.png';

    $(document).ready(function(){
        $('#container img').cacheImages({debug: true});
    });


    var cacheKeys = [],    // Store the keys we need to drop here
        debug = true;
    var setCachedOrLoadImage = function(url, storagePrefix) {
        if( typeof storagePrefix === 'undefined' ){ storagePrefix = 'cached'; }
        var cacheKeys = [];    // Store the keys we need to drop here

        // Lets get our loop on
        if($.fn.cacheImages.defaults.storageDB == 'localStorage') {
            // Using Local Storage
            for (i = 0; i < window.localStorage.length; i++) {
                if(window.localStorage.key(i).substr(0, storagePrefix.length + 1) !== storagePrefix + ':') {
                     continue;
                }
                // Does not match our prefix?
                cacheKeys.push(window.localStorage.key(i).substr(storagePrefix.length + 1));
                // Droping the keys here re-indexes the localStorage so that the offset in our loop is wrong
            }

            setImage(cacheKeys, url, storagePrefix);
        } else {
            var request = window.cacheImagesDb.transaction("offlineImages", "readonly").objectStore("offlineImages").openCursor();
            request.onsuccess = function(e) {
                var cursor = e.target.result;
                if (cursor) {
                    // Called for each matching record.
                    if (cursor.value.key.substr( 0,storagePrefix.length + 1) === storagePrefix + ':') {
                        // Does not match our prefix?
                        cacheKeys.push(cursor.value.key.substr(storagePrefix.length + 1));
                    }
                    cursor.continue();
                } else {
                    setImage(cacheKeys, url, storagePrefix);
                }
            };
        }

        return true;
    },
    setImage = function(cacheKeys, url, storagePrefix) {
        let elements = cacheKeys.filter(function(elem) {
            return elem !== 'pending' && elem !== 'error';
        });
        if (elements.includes(url)) {
            //element.cacheImages({ url: url });

            // if( $('#' + cacheKeys[i] ).length > 0 ){ continue; }
                //if(  window.localStorage.getItem( cacheKeys[i] ) === 'pending' ){ continue; }
                //if(  window.localStorage.getItem( cacheKeys[i] ) === 'error' ){ continue; }


            // Display using teh cacheImages Output() function via the callback.
            $.fn.cacheImages.Output(url, function(image) {
                console.log( image.substr(0, 50));
                $('img').attr('src', image);
            }, storagePrefix, true);
        } else {
            $('img').attr('src', url);
        }
    }
    */ 
