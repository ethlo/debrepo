#!/bin/bash
#
#   Copyright 2017 Morten Haraldsen - https://github.com/ethlo/debrepo
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

### START OF CONFIG ###
ORG_NAME="Acme Corp"
ORG_ALIAS="acme"
KEYID="no-spam@acme.com"
DEB_REPO=~/debrepo/packages
WORK_DIR=~/debrepo/work
KEY_SERVER="keyserver.ubuntu.com"
### END OF CONFIG ###

install_deps() {
  apt-get update
  apt install haveged -y
  apt install inotify-tools -y
}

rename_debs() {
    dir=$1
    for filename in "$dir"/*.deb; do
        deb_info=`dpkg --info "$filename" |  egrep "Version|Package|Architecture"`
        name=`echo $deb_info | cut -d ' ' -f2`
        arch=`echo $deb_info | cut -d ' ' -f6`
        version=`echo $deb_info | cut -d ' ' -f4`
        newfile="$name"_"$arch"_"$version".deb
        if [ "$filename" != "$dir/$newfile" ]; then
                mv "$filename" "$dir/$newfile"
                echo "$newfile"
        fi
    done
}

export() {
    target="$DEB_REPO/$ORG_ALIAS.asc"
    echo "Exporting public key to '$target'"
    gpg --homedir "$WORK_DIR/gpg" --no-default-keyring --keyring "$WORK_DIR/gpg/keyring" --export -a $KEYID > $target
}

update_repo() {
    flavor=$1;

    # Sign individual DEB packages
    #find "$DEB_REPO/$flavor" -maxdepth 1 -type f -name *.deb -exec dpkg-sig --sign builder '{}' \;

    if [ ! -d "$DEB_REPO/$flavor" ]; then
      echo "No directory for flavor '$flavor' in $DEB_REPO"
      exit 1
    fi

    echo "Packages"
    db="$WORK_DIR/${flavor}_index.db"
    cd "$DEB_REPO"
    apt-ftparchive packages "$flavor" --db "$db" > "$DEB_REPO/$flavor/Packages"
    
    echo "Packages.gz"
    gzip -c "$flavor/Packages" > "$flavor/Packages.gz"
    
    echo "Release config"
    cat > "$WORK_DIR/apt-release.conf" <<- EOF
	#Auto-generated, do not edit!   
	APT::FTPArchive::Release::Suite "$flavor";
 	APT::FTPArchive::Release::Architectures "all";
	APT::FTPArchive::Release::Description "$ORG_NAME $flavor repository";
EOF

    echo "Release"
    apt-ftparchive release --db index.db -c "$WORK_DIR/apt-release.conf" $flavor > "$DEB_REPO/$flavor/Release"

    echo "Sign Release files"
    rm -f "$DEB_REPO/$flavor/InRelease" "$DEB_REPO/$flavor/Release.gpg" 
    gpg --homedir "$WORK_DIR/gpg" --no-default-keyring --keyring "$WORK_DIR/gpg/keyring" --digest-algo SHA512 -u "$KEYID" --clearsign -o "$DEB_REPO/$flavor/InRelease" "$DEB_REPO/$flavor/Release"
    gpg --homedir "$WORK_DIR/gpg" --no-default-keyring --keyring "$WORK_DIR/gpg/keyring" --digest-algo SHA512 -u "$KEYID" -abs -o "$DEB_REPO/$flavor/Release.gpg" "$DEB_REPO/$flavor/Release"
}

function publish_key() {
  gpg --homedir "$WORK_DIR/gpg" --no-default-keyring --keyring "$WORK_DIR/gpg/keyring" --send-keys --keyserver "$KEY_SERVER" 
}

function init() {
  if [ ! -d "$WORK_DIR" ]; then
    echo "Creating work directory: $WORK_DIR"
    mkdir -p "$WORK_DIR"    
  fi

  if [ ! -d "$DEB_REPO" ]; then
    echo "Creating debian repository directory: $DEB_REPO"
    mkdir -p "$DEB_REPO"
  fi

  pre_check

  create_keys

  publish_key
}

function create_keys() {
  if [ ! -d "$WORK_DIR/gpg" ]; then
    echo 'Initializing GPG keyring'
    mkdir -p "$WORK_DIR/gpg"
    chmod 700 "$WORK_DIR/gpg"
    gpg --homedir "$WORK_DIR/gpg" --no-default-keyring --keyring "$WORK_DIR/gpg/keyring" --fingerprint
  fi
	
  cat > "$WORK_DIR/key.spec" <<- EOF
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

  gpg --homedir "$WORK_DIR/gpg"  --no-default-keyring --keyring "$WORK_DIR/gpg/keyring" --list-keys "$KEYID" &>/dev/null
  if [ $? -ne 0 ]; then
    echo "Creating GPG keys"
    gpg --homedir "$WORK_DIR/gpg" --no-default-keyring --keyring "$WORK_DIR/gpg/keyring" --batch --gen-key "$WORK_DIR/key.spec" 
  else
    echo "GPG key $KEYID already exists"
    exit 1
  fi
}



function pre_check() {
  if [ ! -w "$WORK_DIR" ]; then
    echo "Non-writable work directory: $WORK_DIR"
    exit 1
  fi

  if [ ! -w "$DEB_REPO" ]; then
    echo "Non-writable debian repository directory: $DEB_REPO"
    exit 1
  fi
}

case "$1" in

  install-deps)
    install_deps
  ;;

  init)
    init
  ;;

  create-keys)
    create_keys
  ;;
  
  update)
    if [[ $# -ne 2 ]] ; then
	echo "Need sub-directory for debian repo specified, like 'test' or 'stable'"
        exit 1
    fi
    update_repo $2
    ;;

  rename)
    if [[ $# -ne 2 ]] ; then
	echo "Need sub-directory for debian repo specified, like 'test' or 'stable'"
        exit 1
    fi
    rename_debs "$DEB_REPO/$2"
  ;;

  watch)
	while read path action file;
	do
    	    echo "Update due to change of $path$file"
	    flavor=`basename "$path"`
	    update_repo "$flavor"
	done < <(inotifywait -mrq -e close_write "$DEB_REPO")
  ;;

  import-private-key)
    src=${1-text:-"$WORK_DIR/private.key"}
    gpg --homedir "$WORK_DIR/gpg" --no-default-keyring --keyring "$WORK_DIR/gpg/keyring" --allow-secret-key-import --import "$src"
  ;;

  import-public-key)
    src=${1:-"$WORK_DIR/public.asc"}
    gpg --homedir "$WORK_DIR/gpg" --no-default-keyring --keyring "$WORK_DIR/gpg/keyring" --import "$src"
  ;;

  publish-key)
    publish_key
  ;;
  export-public-key)
    export 
  ;;

  export-private-key)
    target=${1:-"$WORK_DIR/private.key"}
    gpg --homedir "$WORK_DIR/gpg" --no-default-keyring --keyring "$WORK_DIR/gpg/keyring" --export-secret-key -a "$KEYID" > "$target"
  ;;  
  *)
    cat << EOF
Usage: $0

  init - attempts to setup a ready repo for you

  install-deps - installs required software

  create-keys - Creates the necessary directories and PGP keys for signing the Release file of the repository

  update <flavor> - Update the repository with any new files added/removed

  watch - Watches the "$DEB_REPO" for changes and calls update when needed

  export-private-key <file> - exports the private key

  export-public-key <file> - exports the public key

  import-private-key <file> - imports the private key

  import-public-key <file> - import the public key

  publish-key - publishes the public key to the key-server '$KEY_SERVER'

  rename - Looks at the metadata in the DEB packages in '$DEB_REPO' and renames them accordingly

EOF
    exit 1
  ;;
esac

