#!/bin/sh

echo "["
speedtest-cli --json --server 4652
echo ","
speedtest-cli --json --server 1907
echo "]"

