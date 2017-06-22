#!/bin/bash

ORG_NAME="Acme AS"
ORG_ALIAS="Acme"
KEYID=no-spam@acme.com
DEB_REPO=/var/www/debian

case "$1" in
  create)
	cat > key.spec <<- EOF
	#Auto-generated, do not edit!	
	%no-protection
	Key-Type: 1
	Key-Length: 4096
	Subkey-Type: 1
	Subkey-Length: 4096
	Name-Real: $ORG_NAME
	Name-Email: $KEYID
	Expire-Date: 0
	EOF

	gpg --list-keys "$KEYID" &>/dev/null
	if [ $? -ne 0 ]; then
		echo "Creating keys"
		gpg --batch --gen-key key.spec 
		gpg --export -a $KEYID > "$ORG_ALIAS.asc"
	else
		echo "GPG key $KEYID already exists"
		exit 1
	fi
    ;;
  update)
    if [[ $# -ne 2 ]] ; then
	echo "Need sub-directory for debian repo specified, like 'test' or 'stable'"
        exit 1
    fi

    # Sign individual DEB packages
    #find "$DEB_REPO/$2" -maxdepth 1 -type f -name *.deb -exec dpkg-sig --sign builder '{}' \;

    cd "$DEB_REPO"

    echo "Packages"
    apt-ftparchive packages $2 --db "$2/index.db" > "$2/Packages"
    echo "Packages.gz"
    gzip -c "$2/Packages" > "$2/Packages.gz"
    echo "Release"

    cat > apt-release.conf <<- EOFF
	#Auto-generated, do not edit!   
	APT::FTPArchive::Release::Suite "$2";
 	APT::FTPArchive::Release::Architectures "all";
	APT::FTPArchive::Release::Description "$ORG_NAME $2 repository";
EOFF

    apt-ftparchive release -c apt-release.conf $2 --db "$2/index.db" > "$2/Release"
    echo "Sign Release files"

    cd "$2"
    #echo `pwd` 
    rm -f InRelease Release.gpg 
    gpg --digest-algo SHA512 --clearsign -o InRelease Release
    gpg --digest-algo SHA512 -abs -o Release.gpg Release
    ;;
  *)
    echo "Usage: $0 {create|update}" >&2
    exit 1
    ;;
esac
