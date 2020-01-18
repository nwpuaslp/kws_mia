#!/bin/bash

dict_dir=data/dict
stage=0
if [ ! -d dict_dir ];then
    mkdir -p  $dict_dir
fi

if [ $stage -le 0 ];then
    echo \ 
"<SPOKEN_NOISE> sil
<gbg> <GBG>
你好米雅 n i3 h ao3 m i3 ii ia3" > $dict_dir/lexicon.txt
fi

if [ $stage -le 1 ];then
    awk '{for(i=2;i<=NF;i++){if($i!=sil){print $i}}}' $dict_dir/lexicon.txt | sort -k 1 | uniq > $dict_dir/nonsilence_phones.txt
    echo "sil" > $dict_dir/silence_phones.txt
    echo "sil" > $dict_dir/optional_silence.txt
fi

if [ $stage -le 2 ];then
    echo \ 
"sil
<GBG>
ao3
h
i3 ia3 ii
m
n" > $dict_dir/extra_questions.txt
fi