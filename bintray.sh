#!/bin/bash
#
# Upload DEB package files to Bintray
# Usage: bintray.sh /tmp/rtorrent-ps-ch-dist/rtorrent-ps-ch_1.8.0-0.9.7-ubuntu-bionic_amd64.deb /tmp/rtorrent-ps-ch-dist/rtorrent-ps-ch_1.8.0-0.9.7-ubuntu-bionic_amd64.tar.gz
#
set -e

[[ -z "${BINTRAY_API_KEY+x}" ]] && echo "You MUST set the Bintray API key!" && exit 1


# Config
bintray_account="chros73"
bintray_project="rtorrent-ps-ch"
url_base="https://api.bintray.com"
curl_bin=(curl -H Content-Type:application/json -H Accept:application/json -u"$bintray_account":"$BINTRAY_API_KEY" -X PUT)
showfile_delay=10


# Loop over all arguments
for path in "$@"; do
    test -f "$path" || { echo "$path is not a package file"; exit 1; }

    # Extract metadata
    filename=${path##*/}

    version=${filename#*_}
    version=${version%-*}
    version=${version%-*}

    arc=${filename##*_}
    arc=${arc/.*}

    dist=${filename##*-}
    dist=${dist/_*}

    # Build API URLs
    url_upload="$url_base/content/$bintray_account/$bintray_project/$bintray_project/$version/$filename;deb_distribution=$dist;deb_component=net;deb_architecture=$arc;publish=1"
    url_show="$url_base/file_metadata/$bintray_account/$bintray_project/$filename"

    # Perform the upload
    echo "Uploading and publishing to $url_upload ..."
    ${curl_bin[@]} --progress-bar -T "$path" "$url_upload"
    echo

    for i in $(seq ${showfile_delay:-9} -1 1); do echo -ne " $i  "'\r'; sleep 1; done; echo -e '\r     \r'

    echo "Displaying $filename in download list using $url_show ..."
    ${curl_bin[@]} "$url_show" -d '{ "list_in_downloads": true }'
    echo
done

echo
echo "Open ${url_base/api./}/$bintray_account/$bintray_project/$bintray_project/$version to view upload results."
echo

    # Extract metadata
    filename=${debfile##*/}
    version=$(dpkg-deb -f "$debfile" Version)
    arch=$(dpkg-deb -f "$debfile" Architecture)
    section=$(dpkg-deb -f "$debfile" Section)
    distro=${version##*~}
    version=${version%%~*}

    # Build API URLs
    upload_url="$BASE_URL/content/$BINTRAY_ACCOUNT/${BINTRAY_PROJECT}/${BINTRAY_PROJECT}/$version/$filename"
    upload_url="$upload_url;deb_distribution=$distro;deb_component=${section};deb_architecture=$arch;publish=1"
    showfile_url="$BASE_URL/file_metadata/$BINTRAY_ACCOUNT/${BINTRAY_PROJECT}/$filename"

    # Perform the upload
    echo "Uploading and publishing to $upload_url ..."
    ${CURL_BIN[@]} --progress-bar -T "$debfile" "$upload_url"
    echo

    for i in $(seq ${SHOWFILE_DELAY:-9} -1 1); do echo -ne " $i  "'\r'; sleep 1; done; echo -e '\r     \r'

    echo "Displaying $filename in download list using $showfile_url ..."
    ${CURL_BIN[@]} "$showfile_url" -d '{ "list_in_downloads": true }'
    echo
done

echo
echo "Open ${BASE_URL/api./}/$BINTRAY_ACCOUNT/${BINTRAY_PROJECT}/${BINTRAY_PROJECT}/$version to view upload results."
