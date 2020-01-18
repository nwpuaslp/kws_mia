# !/bin/bash

. ./path.sh
. ./cmd.sh

lats_dir=$1
to_dir=$2
dest_dir=$to_dir/copy_lats
[ ! -d $dest_dir ] && mkdir -p $dest_dir

nj=`cat $to_dir/num_jobs`

$train_cmd JOB=1:$nj $dest_dir/log/copy_lats.JOB.log \
   lattice-copy "ark:gunzip -c $lats_dir/lat.JOB.gz |" ark,scp:$PWD/$dest_dir/lat.JOB.ark,$PWD/$dest_dir/lat.JOB.scp || exit 1;

cat $dest_dir/lat.*.scp > $dest_dir/lat.scp
