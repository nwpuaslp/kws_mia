#!/bin/bash

order=3
prune="1 1 5"
tmp=data/lm/tmp
mem_rate=40%
output_dir=
arpa_name=
fallback="0.5 1 1.5"

input=$1

cat $input | local/lmplz \
    -o $order \
    -T $tmp \
    -S $mem_rate \
    --prune $prune \
    --discount_fallback $fallback \
    --arpa $2
