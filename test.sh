#!/bin/bash

sudo ./debrepo.sh install-deps

./debrepo.sh init


./debrepo.sh export-public-key

mkdir ~/debrepo/packages/test
wget -q -O ~/debrepo/packages/test/curl.deb http://security.debian.org/debian-security/pool/updates/main/c/curl/curl_7.26.0-1+wheezy19_amd64.deb
./debrepo.sh rename test
./debrepo.sh update test
