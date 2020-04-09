#!/bin/bash

stage=0

data_train_root=/home/backup_nfs2/zhyyao/kws_mia/train
data_dev_root=/home/backup_nfs2/zhyyao/kws_mia/dev
data_test_root=/home/backup_nfs2/zhyyao/kws_mia/test

data_train=data/kws/train
data_test=data/kws/test
data_dev=data/kws/dev
mkdir -p $data_train
mkdir -p $data_test
mkdir -p $data_dev
echo "prepare kws data"
if [ $stage -le 0 ];then
    
    if [ -f $data_train_root/SPEECHDATA/train.scp ];then
        awk '{print "/home/backup_nfs2/zhyyao/kws_mia/train/SPEECHDATA/"$0 }' $data_train_root/SPEECHDATA/train.scp > $data_train_root/SPEECHDATA/train_p.scp
        mv $data_train_root/SPEECHDATA/train_p.scp  $data_train/wav.scp
    fi
    if [ -f $data_dev_root/SPEECHDATA/dev.scp ];then
        awk '{print "/home/backup_nfs2/zhyyao/kws_mia/dev/SPEECHDATA/"$0 }' $data_dev_root/SPEECHDATA/dev.scp > $data_dev_root/SPEECHDATA/dev_p.scp
        mv $data_dev_root/SPEECHDATA/dev_p.scp  $data_dev/wav.scp
    fi
    awk '{print "/home/backup_nfs2/zhyyao/kws_mia/test/wav/"$0}' $data_test_root/wav.scp > $data_test_root/test_p.scp
	mv $data_test_root/test_p.scp $data_test/wav.scp
fi

if [ $stage -le 1 ];then
    for i in $data_train $data_dev $data_test;do
        cat $i/wav.scp | while read line;do
            line_p1=${line##*/}
            echo ${line_p1%.*} $line
        done > $i/wav_terminal.scp
        mv $i/wav_terminal.scp $i/wav.scp
    done
fi

if [ $stage -le 2 ];then
    for i in $data_train $data_dev $data_test;do
		awk '{split($1,array,"_");print $1,array[1]}' $i/wav.scp> $i/utt2spk
        local/utt2spk_to_spk2utt.pl $i/utt2spk > $i/spk2utt
		utils/fix_data_dir.sh $i
	done
fi
