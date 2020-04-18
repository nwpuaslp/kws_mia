#!/bin/bash


data=/home/work_nfs2/xshi/corpus/aishell1
data_aishell=data/aishell
data_kws=data/kws
data_url=www.openslr.org/resources/33
kws_url=www.openslr.org/resources/85

ali=exp/tri3a_merge_ali
other_ali=exp/tri3a_ali
kws_ali=exp/tri3a_kws_ali
feat_dir=data/fbank

kws_dict=data/dict

kws_word_split="你好 米 雅"
kws_word="你好米雅"
kws_phone="n i3 h ao3 m i3 ii ia3"

stage=11

# if false we will not train aishell model,
do_train_aishell1=$false

. ./cmd.sh
. ./path.sh

if [ $stage -le 0 ]; then
	if [ $do_train_aishell1 ];then
		echo "do aishell 1"
		local/download_and_untar.sh $data_aishell $data_url data_aishell.tgz || exit 1;
		local/download_and_untar.sh $data_aishell $data_url resource_aishell.tgz || exit 1;
	fi
	# local/download_and_untar.sh $data_kws $kws_url dev.tar.gz || exit 1;
	# local/download_and_untar.sh $data_kws $kws_url test.tar.gz || exit 1;
	# local/download_and_untar.sh $data_kws $kws_url train.tar.gz ||exit 1;
	# You should write your own path to this script
	local/prepare_kws.sh || exit 1;
fi
if [ $stage -le 1 ]; then
	if [ $do_train_aishell1 ];then
		# Lexicon Preparation,
		local/aishell_prepare_dict.sh data/aishell/local || exit 1;

		# Data Preparation,
		local/aishell_data_prep.sh $data/wav $data/transcript || exit 1;

		# Phone Sets, questions, L compilation
		utils/prepare_lang.sh --position-dependent-phones false $data_aishell/local/dict \
			"<SPOKEN_NOISE>" $data_aishell/local/lang $data_aishell/lang || exit 1;

		# LM training
		local/aishell_train_lms.sh || exit 1;

		# G compilation, check LG composition
		utils/format_lm.sh $data_aishell/lang $data_aishell/local/lm/3gram-mincount/lm_unpruned.gz \
			$data_aishell/local/dict/lexicon.txt $data_aishell/lang_test || exit 1;
	fi
fi

# Prepare mfcc for aishell and kws
if [ $stage -le 2 ];then
	mfccdir=mfcc
	for x in  train dev test; do
		if [ $do_train_aishell1 ];then
			steps/make_mfcc.sh --cmd "$train_cmd" --nj 10 $data_aishell/$x exp/make_mfcc/aishell/$x $data_aishell/$mfccdir || exit 1;
			steps/compute_cmvn_stats.sh $data_aishell/$x exp/make_mfcc/aishell/$x $data_aishell/$mfccdir || exit 1;
			utils/fix_data_dir.sh $data_aishell/$x || exit 1;
		fi
		steps/make_mfcc.sh --cmd "$train_cmd" --nj 10 $data_kws/$x exp/make_mfcc/kws/$x $data_kws/$mfccdir || exit 1;
		steps/compute_cmvn_stats.sh $data_kws/$x exp/make_mfcc/kws/$x $data_kws/$mfccdir || exit 1;
		utils/fix_data_dir.sh $data_kws/$x || exit 1;
	done
fi

if [ $do_train_aishell1 ];then

if [ $stage -le 3 ];then
	steps/train_mono.sh --cmd "$train_cmd" --nj 10 \
		$data_aishell/train $data_aishell/lang exp/mono || exit 1;
	steps/align_si.sh --cmd "$train_cmd" --nj 10 \
		$data_aishell/train $data_aishell/lang exp/mono exp/mono_ali || exit 1;
fi

if [ $stage -le 4 ];then
	steps/train_deltas.sh --cmd "$train_cmd" \
		2500 20000 $data_aishell/train $data_aishell/lang exp/mono_ali exp/tri1 || exit 1;
	steps/align_si.sh --cmd "$train_cmd" --nj 10 \
		$data_aishell/train $data_aishell/lang exp/tri1 exp/tri1_ali || exit 1;
fi

if [ $stage -le 5 ];then
	steps/train_deltas.sh --cmd "$train_cmd" \
		2500 20000 $data_aishell/train $data_aishell/lang exp/tri1_ali exp/tri2 || exit 1;
	steps/align_si.sh --cmd "$train_cmd" --nj 10 \
		$data_aishell/train $data_aishell/lang exp/tri2 exp/tri2_ali || exit 1;
fi

if [ $stage -le 6 ];then
	steps/train_lda_mllt.sh --cmd "$train_cmd" \
		2500 20000 $data_aishell/train $data_aishell/lang exp/tri2_ali exp/tri3a || exit 1;
fi

fi

if [ $stage -le 7 ];then
# use aishell tri3a align kws data
	for i in train dev test;do
		echo $kws_word_split
		awk '{print $1}' $data_kws/$i/wav.scp | while read line; do echo $line" "$kws_word_split;done >$data_kws/$i/text
		#awk -v word=$kws_word_split '{print $1,word}' $data_kws/$i/wav.scp> $data_kws/$i/text 
	done
	for i in utt2spk spk2utt feats.scp cmvn.scp text wav.scp;do
		cat $data_kws/train/$i $data_kws/test/$i $data_kws/dev/$i > $data_kws/$i
	done

	mkdir -p data/merge
	for i in train dev test;do
		mkdir -p data/merge/$i
		for j in utt2spk spk2utt feats.scp cmvn.scp text wav.scp;do
			cat $data_aishell/$i/$j $data_kws/$i/$j > data/merge/$i/$j
		done
		utils/fix_data_dir.sh data/merge/$i || exit 1;
	done

	cat $data_aishell/test/wav.scp | awk '{print $1, 0}' > data/merge/negative
	cat $data_kws/test/wav.scp | awk '{print $1, 1}' > data/merge/positive
	test_merge_data=data/merge
	cat $test_merge_data/negative $test_merge_data/positive | sort > data/merge/label
	rm data/merge/negative
	rm data/merge/positive
	
	steps/align_fmllr.sh --cmd "$train_cmd" --nj 50 \
      		data/merge/train $data_aishell/lang exp/tri3a $ali || exit 1;
fi

if [ $stage -le 8 ];then
	[ ! -d $kws_dict ] && mkdir -p $kws_dict;
    echo "Prepare keyword phone & id"

	cat <<EOF > $kws_dict/lexicon.txt
sil sil
<SPOKEN_NOISE> sil
<gbg> <GBG>
$kws_word $kws_phone
EOF
	echo "<eps> 0
sil 1" > $kws_dict/phones.txt
	count=2
    awk '{for(i=2;i<=NF;i++){if(!match($i,"sil"))print $i}}' $kws_dict/lexicon.txt | sort | uniq  | while read line;do
		echo "$line $count"
		count=`expr $count + 1`
	done >> $kws_dict/phones.txt
	cat <<EOF > $kws_dict/words.txt
<gbg> 0
$kws_word 1
EOF
fi

if [ $stage -le 9 ];then
	echo "merge and change alignment"
    awk -v hotword_phone=$kws_dict/phones.txt \
    'BEGIN {
        while (getline < hotword_phone) {
            map[$1] = $2 
        }
    }
    {
        if(!match($1, "#") && !match($1, "<")) { 
			if(match($1, "sil"))
			{
				printf("%s %s\n", $2, 1)
			}
			else
			{
				printf("%s %s\n", $2, map[$1] != "" ? map[$1] : 2)
			}
        }
    }
    ' $data_aishell/lang/phones.txt > data/phone.map
	mkdir -p exp/kws_ali_test
	cur=`cat $ali/num_jobs`
	for x in `seq 1 $cur`;do
		gunzip -c $ali/ali.$x.gz | 
		ali-to-phones --per-frame=true exp/tri3a/final.mdl ark:- t,ark:- | 
		utils/apply_map.pl -f 2- data/phone.map |
		copy-int-vector t,ark:- ark,scp:exp/kws_ali_test/ali.$x.ark,exp/kws_ali_test/ali.$x.scp 
	done
	cat exp/kws_ali_test/ali.*.scp | sort -k 1 > exp/kws_ali_test/ali.scp
	cp $ali/final.mdl exp/kws_ali_test || exit 1;
	cp $ali/num_jobs exp/kws_ali_test || exit 1;
	cp $ali/tree exp/kws_ali_test || exit 1;
	cp $kws_dict/phones.txt exp/kws_ali_test || exit 1;
	ali=exp/kws_ali_test
fi

if [ $stage -le 0 ];then
	echo "Extracting feats & Create tr cv set"
	[ ! -d $feat_dir ] && mkdir -p $feat_dir
    [ ! -d data/wav ] && ln -s $data_aishell/wav data/
    cp -r data/merge/train $feat_dir/train
    cp -r data/merge/test $feat_dir/test
    steps/make_fbank.sh --cmd "$train_cmd" --fbank-config conf/fbank71.conf --nj 50 $feat_dir/train $feat_dir/log $feat_dir/feat || exit 1;
    steps/make_fbank.sh --cmd "$train_cmd" --fbank-config conf/fbank71.conf --nj 50 $feat_dir/test $feat_dir/log $feat_dir/feat || exit 1;
    compute-cmvn-stats --binary=false --spk2utt=ark:$feat_dir/train/spk2utt scp:$feat_dir/train/feats.scp ark,scp:$feat_dir/feat/cmvn.ark,$feat_dir/train/cmvn.scp || exit 1;
	utils/fix_data_dir.sh $feat_dir/train
	utils/fix_data_dir.sh $feat_dir/test
fi
# train
if [ $stage -le 11 ];then
	num_targets=`wc -l $kws_dict/phones.txt`
	local/nnet3/run_tdnn.sh --num_targets $num_targets
fi

# p
if [ $stage -le 12 ];then
	steps/nnet3/make_bottleneck_features.sh  \
		--use_gpu true \
		--nj 1 \
		output.log-softmax \
		data/fbank/test \
 		data/fbank/test_bnf \
 		exp/nnet3/tdnn_test_kws \
 		exp/bnf/log \
 		exp/bnf || exit 1;
fi

if [ $stage -le 13 ];then
	copy-matrix ark:exp/bnf/raw_bnfeat_test.1.ark t,ark:exp/bnf/ark.txt
	python local/kws_posterior_handling.py exp/bnf/ark.txt
	python local/kws_draw_ros.py result.txt data/merge/label
fi
