#!/bin/bash

# Colors
LR="\033[1;31m"
LP="\033[1;35m"
LG="\033[1;32m"
NC="\033[0m"

deps=()

function parse_deps() {
    local exclude_list=("appcompat" "junit" "material" "constraintlayout" "test" "exif")
    local gradle_file="../../build.gradle.kts"
    local identifier="implementation(\""
    local cameraLibsVersion=`grep "val cameraVersion" $gradle_file | sed 's/val cameraVersion =//' | sed 's/"//g' | xargs`
    local line=
    while read line; do
        if [[ $line == *"$identifier"* ]]; then
            local lib=$(echo $line | sed "s/$identifier//; s/\")//")
            local element=
            for element in ${exclude_list[@]}; do
                if echo $lib | grep -q $element; then
                    continue 2
                fi
            done
            lib=`echo $lib | sed 's/$cameraVersion/'$cameraLibsVersion'/g'`
            echo -e "${LG}Parsed $lib${NC}"
            deps+=( $lib )
        fi
    done < $gradle_file

    local additional_deps=("androidx.concurrent:concurrent-futures:1.0.0 androidx.databinding:viewbinding:7.2.1")
    local dep=
    for dep in ${additional_deps[@]}; do
        deps+=( $dep )
    done
}

function get_destination() {
    local root_dir="libs"
    local top_dir=$(echo $1 | awk -F: '{print $1}')
    local sub_dir=$(echo $1 | awk -F: '{print $2}')
    echo "$root_dir/$top_dir/$sub_dir"
}

function get_file_name() {
    local prefix=$(echo $1 | awk -F: '{print $1}')
    local file_name=$(echo $1 | sed "s/$prefix://; s/:/-/")
    local ext=$(get_extension $1)
    echo "$file_name$ext"
}

function get_dl_url() {
    local maven2_dl_google="https://dl.google.com/dl/android/maven2"
    local maven2_dl_repo1="https://repo1.maven.org/maven2"

    if [[ $1 == *"zxing"* ]]; then
        local url_base=$maven2_dl_repo1
    else
        local url_base=$maven2_dl_google
    fi

    local file_name=$(get_file_name $1)

    local url_part1=$(echo $1 | awk -F: '{print $1}' | sed 's|\.|/|g')
    local url_part2=$(echo $1 | awk -F: '{print $2}')
    local version=$(echo $1 | awk -F: '{print $3}')

    echo "$url_base/$url_part1/$url_part2/$version/$2"
}

function get_extension() {
    local ext_aar=".aar"
    local ext_jar=".jar"
    local jar_list=( "concurrent-futures" "zxing:core" "lifecycle-common-java8" "listenablefuture" )
    local ext=$ext_aar
    local jar=
    for jar in ${jar_list[@]}; do
        if echo $1 | grep -q $jar; then
            ext=$ext_jar
            break
        fi
    done
    echo $ext
}

function download_all() {
    local dep=
    for dep in ${deps[@]}; do
        dest=$(get_destination $dep)
        file_name=$(get_file_name $dep)
        url=$(get_dl_url $dep $file_name)
        echo -e "${LG}Downloading $file_name from $url...${NC}"
        wget -q $url -O "$dest/$file_name"
        if [[ $? -ne 0 ]]; then
            echo -e "${LR}Download failed for $file_name${NC}"
        fi
    done
}

function clean_dest() {
    local dep=
    for dep in ${deps[@]}; do
        local dest=$(get_destination $dep)
        if [ -d $dest ]; then
            echo -e "${LP} Cleaning $dest${NC}"
            rm -rf $dest/*
        else
            mkdir -p $dest
        fi
    done
}

if ! command -v wget &> /dev/null; then
    echo -e "${LR}wget not found, aborting!${NC}"
    exit 1
fi

parse_deps
clean_dest
download_all
