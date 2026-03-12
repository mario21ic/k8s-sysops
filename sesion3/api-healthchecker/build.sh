#!/bin/bash

set -xe

VERSION=$1
#cp versions/main_v1.0.py app/main.py && docker build --platform=linux/amd64 -t mario21ic/api-healthchecker:1.0 ./
cp versions/main_v${VERSION}.py app/main.py && docker build --platform=linux/amd64 -t mario21ic/api-healthchecker:${VERSION} ./
