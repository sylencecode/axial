#!/bin/sh

while [ 1 ]; do
  git pull
  sleep 5
  ./efnet.rb
done
