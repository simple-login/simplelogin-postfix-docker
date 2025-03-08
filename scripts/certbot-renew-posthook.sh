#!/usr/bin/env bash

set -e

/src/generate_config.py --postfix
postfix reload
