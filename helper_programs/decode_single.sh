#!/bin/bash
#PBS -q isi
#PBS -l walltime=336:00:00
#PBS -l gpus=2

tmpdir=${TMPDIR:-/tmp}
MTMP=$(mktemp -d --tmpdir=$tmpdir XXXXXX)
function cleanup() {
    rm -rf $MTMP;
}
trap cleanup EXIT


#### Sets up environment to run code ####
source /usr/usc/cuda/7.0/setup.sh
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/nlg-05/zoph/cudnn_v4/lib64/
export LD_LIBRARY_PATH

FINAL_ARGS=$1
ORIG_DATA=$2
BLEU_FORMAT=$3
OUTPUT_FILE=$4
TTABLE=$5
UNK_REP=$6
DECODE_FORMAT=$7
FINAL_DATA=""
echo "FINAL_ARGS = $FINAL_ARGS"
echo "ORIG_DATA = $ORIG_DATA"
for i in $( seq 1 8 ); do 
	cp $ORIG_DATA  $MTMP"/src_data${i}.txt"
	FINAL_DATA=$FINAL_DATA" src_data${i}.txt"
done
echo "FINAL_DATA = $FINAL_DATA"
echo "MTMP = $MTMP"
cd $MTMP/
touch "tmp.txt"
FINAL_ARGS=$FINAL_ARGS" --kbest-source-files-main $FINAL_DATA --UNK-decode unks.txt"
echo $FINAL_ARGS
$FINAL_ARGS
cp $OUTPUT_FILE "tmp.txt"
python $BLEU_FORMAT $OUTPUT_FILE
UNK_REP="$UNK_REP $ORIG_DATA $OUTPUT_FILE $TTABLE unks.txt"
python $UNK_REP
python $DECODE_FORMAT $OUTPUT_FILE "tmp.txt"
exit 0