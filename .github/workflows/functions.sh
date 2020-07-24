#!/bin/bash

function create_data_json()
{
  VERSION_DATE=$(echo "${FULL_PACKAGE_VERSION}" | sed "s/[^-]*-a.0.\([0-9]*\).*/\1/")

  cat << DATA_JSON > ../data.json
{
  "version" : "${VERSION}",
  "major_minor_version": "${MAJOR_MINOR_VERSION}",
  "version_date" : "${VERSION_DATE}",
  "rfc_email_date": "$(date -R)"
}
DATA_JSON

  echo "=== ../data.json ==="
  cat ../data.json
}

function create_bash_config()
{
  cat << DATA_JSON > ../runtime_config.sh
UPSTREAM_FILE_NAME="$UPSTREAM_FILE_NAME"
FULL_PACKAGE_VERSION="$FULL_PACKAGE_VERSION"
VERSION="$VERSION"
MAJOR_MINOR_VERSION="$MAJOR_MINOR_VERSION"
DATA_JSON

  echo "=== ../runtime_config.sh ==="
  cat ../runtime_config.sh
}

function create_runtime_config()
{
  local USCAN_LOG=$1

  UPSTREAM_FILE_NAME=$(grep "Filename.*for downloaded file" ${USCAN_LOG} | sed "s/.*downloaded file:[ ]*//")
  echo UPSTREAM_FILE_NAME = $UPSTREAM_FILE_NAME

  FULL_PACKAGE_VERSION=$(ls -1 ../*orig.tar.xz | head -1 | sed 's/\(.*_\)\(.*\)\(\.orig.*\)/\2/');
  echo FULL_PACKAGE_VERSION = $FULL_PACKAGE_VERSION;

  VERSION=$(echo "${FULL_PACKAGE_VERSION}" | sed "s/\([^-]*\)-.*/\1/")
  echo VERSION = $VERSION

  MAJOR_MINOR_VERSION=$(echo "${FULL_PACKAGE_VERSION}" | sed "s/\([^.]*\).\([^.]*\).\([^.]*\).*/\1.\2/")
  echo MAJOR_MINOR_VERSION = $MAJOR_MINOR_VERSION

  create_data_json
  create_bash_config
}

function render_templates()
{
  . ../runtime_config.sh

  pushd .
  cd debian/templates

  ls -1 *0.13* | while read f;
  do
    new_f=$(echo $f|sed s/0\.13/$MAJOR_MINOR_VERSION/);
    mv "$f" "$new_f";
  done
  echo "=== updated templates ==="
  ls -la .

  npm install -g ejs
  echo "=== post ejs install ==="
  ls -1 *ejs | while read f;
  do
    out_file=$(echo "$f"| sed "s/\(.*\).ejs/\1/")
    npx ejs -f ../../../data.json "$f" -o ../"$out_file"
    chmod --reference="$f" ../"$out_file"
  done
  popd
}

function update_debian_dir_push_to_focal_new()
{
  render_templates
  rm -rf debian/templates

  echo "=== git status ==="
  git status

  git checkout -b ubuntu/focal_new
  git config --global user.email "pioneer19@mailo.com"
  git config --global user.name  "Alex Syrnikov"
  git add debian
  git commit -m "updated debian dir from templates"
  echo "=== git remote -v"
  git remote -v
  git push origin +ubuntu/focal_new
}

function update_symbols()
{
    echo "=== updating symbols ==="
    git clean -dxf
    git restore .
    . ../runtime_config.sh
    pkgkde-symbolshelper batchpatch -v ${VERSION} ../build.log
    local files_count=$(git status -s debian/*symbols | wc -l)
    if [[ $files_count -eq 0 ]]
    then
        echo "update_symbols did not update any files"
        return 1
    fi

    git status -s debian/*symbols | while read unused f;
    do
        grep -v MISSING "$f" > 1
        mv 1 "$f"
        git add "$f"
        echo "=== updated symbols $f"
    done
    git commit -m "updated symbol files"
    git push origin ubuntu/focal_new

    echo "git status"
    git status
}

function install_debs_and_remove_files()
{
    local package_name=$1

    dpkg -i ../*.deb
    rm ../*deb
    rm ../${package_name}_*
    echo "=== ls -la ../"
    ls -la ../
}
