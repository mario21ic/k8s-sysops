#!/bin/bash
set -xe

VERSION=$1
docker run --platform=linux/amd64 -p 5001:5001 mario21ic/api-healthchecker:${VERSION}
