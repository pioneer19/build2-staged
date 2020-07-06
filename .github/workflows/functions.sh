#!/bin/bash

function import_orig_tar_xz()
{
    echo "=== git remote -v"
    git remote -v

    git checkout upstream/staged
    git checkout -b ubuntu/focal_new origin/ubuntu/focal
    git config --global user.email "pioneer19@mailo.com"
    git config --global user.name  "Alex Syrnikov"
    gbp import-orig -v --debian-branch=ubuntu/focal_new --upstream-branch=upstream/staged --no-interactive $(ls -1 ../*orig*)
    echo "=== git push origin upstream/staged"
    git push origin upstream/staged
}

function get_full_package_version_from_orig()
{
    export FULL_PACKAGE_VERSION=$(ls -1 ../*orig* | head -1 | sed 's/\(.*_\)\(.*\)\(\.orig.*\)/\2/');
    echo FULL_PACKAGE_VERSION = $FULL_PACKAGE_VERSION;
}

function update_changelog()
{
    local package_name=$1

    get_full_package_version_from_orig
    echo "=== env"
    env
    cat << CHANGELOG > debian/changelog
$package_name (${FULL_PACKAGE_VERSION}-20.04ppa1) focal; urgency=low

  * New upstream Release

 -- Alex Syrnikov <pioneer19@mailo.com>  $(date -R)
CHANGELOG
    echo "=== debian/changelog"
    cat debian/changelog

    git add debian
    git commit -m "updated changelog"
    echo "=== git remote -v"
    git remote -v
    git push origin ubuntu/focal_new
}

function update_control()
{
  get_full_package_version_from_orig
  sed -i "s/([-.=0-9a-f]*20.04ppa[0-9]*)/(=${FULL_PACKAGE_VERSION}-20.04ppa1)/" debian/control
  echo "=== cat debian/control"
  cat debian/control
  git status

  git add debian/control
  git commit -m "updated debian/control"
  git push origin ubuntu/focal_new
}

function update_symbols()
{
    echo "updating symbols"
    git clean -dxf
    git restore .
    pkgkde-symbolshelper batchpatch -v 0.13.0 ../build.log
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
    git commit -m "updated symbols files"
    git push origin ubuntu/focal_new

    echo "git status"
    git status
}

function install_debs_and_remove_files()
{
    local package_name=$1

    dpkg -i ../*.deb
    rm ../*deb
    get_full_package_version_from_orig
    rm ../${package_name}_${FULL_PACKAGE_VERSION}-*
    echo "=== ls -la ../"
    ls -la ../
}
