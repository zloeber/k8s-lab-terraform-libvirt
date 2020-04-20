#!/bin/bash
## Install the latest libvirt terraform provider

PROVIDERREPO=dmacvicar/terraform-provider-libvirt 
PROVIDERNAME=terraform-provider-libvirt
ARCH=amd64
OS=`uname -s | tr '[:upper:]' '[:lower:']`
DISTRO=Ubuntu

IGNORED_EXT='(.tar.gz.asc|.txt|.tar.xz|.asc|.MD|.hsm|+ent.hsm|.rpm|.deb|.sha256|.src.tar.gz)'

function get_github_latest_urls {
    # Description: Scrape github releases for most recent release of a project based on:
    # vendor, repo, os, and arch
    local vendorapp="${1?"Usage: $0 vendor/app"}"
    local OS="${OS:-"linux"}"
    local ARCH="${ARCH:-"amd64"}"
    curl -s "https://api.github.com/repos/${vendorapp}/releases/latest" | \
     jq -r --arg OS ${OS} --arg ARCH ${ARCH} \
     '.assets[] | .browser_download_url'
}

latesturl=(`get_github_latest_urls "dmacvicar/terraform-provider-libvirt" | grep -v -E "${IGNORED_EXT}" | grep terraform-provider-libvirt | grep ${DISTRO}`)
applist=()
cnt=${#latesturl[@]}
for ((i=0;i<cnt;i++)); do
    applist+=("${latesturl[i]}")
    applist+=("")
done

mkdir -p ./terraform.d/plugins/linux_amd64/
[ -n "/tmp" ] && [ -n "terraform-provider-libvirt" ] && rm -rf "/tmp/terraform-provider-libvirt"
mkdir -p /tmp/terraform-provider-libvirt
curl --retry 3 --retry-delay 5 --fail -sSL -o - ${applist[0]} | tar -zx -C '/tmp/terraform-provider-libvirt'
find /tmp/terraform-provider-libvirt -type f -name 'terraform-provider-libvirt*' | xargs -I {} cp -f {} ./terraform.d/plugins/linux_amd64/terraform-provider-libvirt
chmod +x ./terraform.d/plugins/linux_amd64/terraform-provider-libvirt
[ -n "/tmp" ] && [ -n "terraform-provider-libvirt" ] && rm -rf "/tmp/terraform-provider-libvirt"
