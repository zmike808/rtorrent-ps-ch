#! /bin/bash
path="$1"
test -f "$path" || { echo "You must provide a package file"; exit 1; }


filename=${path##*/}

version=${filename#*_}
version=${version%-*}
version=${version%-*}

arc=${filename##*_}
arc=${arc/.*}

dist=${filename##*-}
dist=${dist/_*}

url_base="https://api.bintray.com"
url_upload="$url_base/content/$BINTRAY_ACCOUNT/rtorrent-ps-ch/rtorrent-ps-ch/$version/$filename;deb_distribution=$dist;deb_component=net;deb_architecture=$arc;publish=1"
url_show="$url_base/file_metadata/$BINTRAY_ACCOUNT/rtorrent-ps-ch/$filename"

curl_bin=(curl -H Content-Type:application/json -H Accept:application/json -u"$BINTRAY_ACCOUNT":"$BINTRAY_API_KEY" -X PUT)


echo "Uploading and publishing to $url_upload ..."
${curl_bin[@]} --progress-bar -T "$path" "$url_upload"
echo

sleep 10

echo "Displaying $filename in download list using $url_show ..."
${curl_bin[@]} "$url_show" -d "{ \"list_in_downloads\": true }"
echo

