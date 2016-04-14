#!/usr/bin/env bash

#Set Script Name variable
SCRIPT=`basename ${BASH_SOURCE[0]}`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )""/"


#Initialize variables to default values.
SOURCE_TRAIN_FILE="" #Hard path and name of the source file being rescored (e.g. "/home/nlg/source_data.txt")
TARGET_TRAIN_FILE="" #Hard path and name of the target file being rescored (e.g. "/home/nlg/target_data.txt")
SOURCE_DEV_FILE="" #Source dev file (e.g. "/home/nlg/source_dev_data.txt")
TARGET_DEV_FILE="" #Target dev file (e.g. "/home/nlg/target_dev_data.txt")
TRAIN_MODEL_PATH="" #Where the new models will be output to
TRAIN_PARENT_MODEL="0" #1 or 0
MAPPING_SOURCE="" #If training a parent model, then supply child source and target training files too
MAPPING_TARGET="" #If training a parent model, then supply child source and target training files too
PARENT_MODEL_PATH="" #Where the parent models have trained

#Set fonts for Help.
NORM=`tput sgr0`
BOLD=`tput bold`
REV=`tput smso`

#Help function
function HELP {
  echo -e \\n"Help documentation for ${BOLD}${SCRIPT}.${NORM}"\\n
  echo "${BOLD}The following switches are:${NORM}"
  echo "${REV}--train_source${NORM}  : Specify the location of the source training data."
  echo "${REV}--train_target${NORM}  : Specify the location of the target training data." 
  echo "${REV}--dev_source${NORM}  : Specify the location of the source dev data." 
  echo "${REV}--dev_target${NORM}  : Specify the location of the target dev data." 
  echo "${REV}--trained_model${NORM}  : Specify the path to where the models will be trained."
  echo "${REV}--train_parent_model${NORM}  : 1 if training parent models, 0 if training low resource NMT. Default is 0." 
  echo "${REV}--mapping_source_data${NORM}  : If --train_parent_model is 1, then input the location of the child source training data."
  echo "${REV}--mapping_target_data${NORM}  : If --train_parent_model is 1, then input the location of the child target training data."
  echo "${REV}--parent_model${NORM}  : Specify the location of the parent models for option 0. Only do this if you are training pre-initialized child models." 
  echo -e "${REV}-h${NORM}  : Displays this help message. No further functions are performed."\\n
  echo "Example: ${BOLD}$SCRIPT path/to/train_nmt_model.sh --train_source <training_source> --train_target <training_target> --dev_source <dev_source> --dev_target <dev_target> [ --parent_model <parent_model> ] --trained_model <trained_model> --train_parent_model <{0,1}> ${NORM}" 
  exit 1
}

#Check the number of arguments. If none are passed, print help and exit.
NUMARGS=$#

echo "Number of arguements specified: ${NUMARGS}"

if [[ $NUMARGS < 10 ]]; then
    echo -e \\n"Number of arguments: $NUMARGS"
    HELP
fi

### Start getopts code ###

#Parse command line flags
#If an option should be followed by an argument, it should be followed by a ":".
#Notice there is no ":" after "h". The leading ":" suppresses error messages from
#getopts. This is required to get my unrecognized option code to work.


optspec=":h-:"
VAR="1"
NUM=$(( 1 > $(($NUMARGS/2)) ? 1 : $(($NUMARGS/2)) ))
while [[ $VAR -le $NUM ]]; do
while getopts $optspec FLAG; do 
 case $FLAG in
    -) #long flag options
	case "${OPTARG}" in
		train_source)
			echo "train_source : ""${!OPTIND}"	
			SOURCE_TRAIN_FILE="${!OPTIND}"
			;;
		train_target)
			echo "train_target : ""${!OPTIND}"
			TARGET_TRAIN_FILE="${!OPTIND}"
			;;
		dev_source)
			echo "dev_source : ""${!OPTIND}"
			SOURCE_DEV_FILE="${!OPTIND}"		
			;;
		dev_target)
			echo "dev_target : ""${!OPTIND}"
			TARGET_DEV_FILE="${!OPTIND}"
			;;
		trained_model)
			echo "trained_model : ""${!OPTIND}"
			TRAIN_MODEL_PATH="${!OPTIND}"	
			;;
		train_parent_model)
			echo "train_parent_model : ""${!OPTIND}"
			TRAIN_PARENT_MODEL="${!OPTIND}"
			;;
		mapping_source_data)
			echo "mapping_source_data : ""${!OPTIND}"
			MAPPING_SOURCE="${!OPTIND}"
			;;
		mapping_target_data)
			echo "mapping_target_data : ""${!OPTIND}"
			MAPPING_TARGET="${!OPTIND}"
			;;
		parent_model)
			echo "parent_model : ""${!OPTIND}"
			PARENT_MODEL_PATH="${!OPTIND}"			
			;;	
		*) #unrecognized long flag
			echo -e \\n"Option --${BOLD}$OPTARG${NORM} not allowed."
			HELP	
			;;
	esac;;
    h)  #show help
      HELP
      ;;
    \?) #unrecognized option - show help
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      HELP
      #If you just want to display a simple error message instead of the full
      #help, remove the 2 lines above and uncomment the 2 lines below.
      #echo -e "Use ${BOLD}$SCRIPT -h${NORM} to see the help documentation."\\n
      #exit 2
      ;;
  esac
done
VAR=$(($VAR + 1))
#shift $((OPTIND-1))  #This tells getopts to move on to the next argument.
shift 1
done



### End getopts code ###




### Now do arguement checking ###

check_zero_file () {
	if [[ ! -s "$1" ]]
	then
		echo "Error file: ${BOLD}$1${NORM} is of zero size or does not exist"
		exit 1
	fi
}

check_equal_lines () {
	NUM1="$( wc -l $1 | cut -f1 -d ' ' )"
	NUM2="$( wc -l $2 | cut -f1 -d ' ' )"
	if [[ "$NUM1" != "$NUM2" ]]
	then
		echo "Error files: ${BOLD}$1${NORM} and ${BOLD}$2${NORM} are not the same length"
		exit 1
	fi	
}

#Return error if directory exists, if it doesnt then create it
check_location_exists () {
	if [[ -d "$1" ]]
	then
		echo "Error path: ${BOLD}$1${NORM} is already created" 
		exit 1
	else
		mkdir "$1"
	fi
}

#check to see if variable is zero or 1
check_bool () {
	if [[ "$1" -ne "0" ]] && [[ "$1" -ne "1" ]]
	then
		echo "Error flag train_parent_model with value: ${BOLD}$1${NORM} is not equal to 0 or 1"
		exit 1
	fi
}

#checks to see if the parent directory exists, has directories model{1-8} and in each of those directories has a best.nn file
check_parent_structure () {
	
	if [[ -z "$1" ]]
	then
		echo "Error the flag ${BOLD}parent_model${NORM} must be specified" 
		exit 1
	fi
	
	if [[ ! -d "$1" ]]
	then
		echo "Error parent model directory: ${BOLD}$1${NORM} does not exist"
		exit 1
	fi	
	
	for i in $( seq 1 8 )
	do
		if [[ ! -d "$1""model""$i" ]]
		then
			echo "Error directory ${BOLD}model$i${NORM} in parent model directory ${BOLD}$1${NORM} does not exist"
			exit 1
		fi
		
		if [[ ! -s $1"model"$i"/best.nn" ]]
		then
			echo "Error model file ${BOLD}$1"model"$i"/best.nn"${NORM} does not exist"
			exit 1
		fi
	done
}

#Creates the new 8 model directories along with copying in the best.nn files


create_new_dir () {
	for i in $( seq 1 8 )
	do
		mkdir $1"model"$i
		if [[ -n  "$2" ]]
		then
			cp $2"model"$i"/best.nn" $1"model"$i"/parent.nn"
		fi
	done
}

check_dir_final_char () {
	FINAL_CHAR="${1: -1}"
	if [[ $FINAL_CHAR != "/" ]]; then
		return 1
	fi
	return 0
}

check_relative_path () {
	if ! [[ "$DIR" = /* ]]; then
		echo "Error: relative paths are not allowed for any location, ${BOLD}$1${NORM} is a relative path"
		exit 1 
	fi
}

check_relative_path $SOURCE_TRAIN_FILE
check_relative_path $TARGET_TRAIN_FILE
check_relative_path $SOURCE_DEV_FILE
check_relative_path $TARGET_DEV_FILE
check_relative_path "$TRAIN_MODEL_PATH"


check_dir_final_char "$TRAIN_MODEL_PATH"
BOOL_COND=$?
if [[ "$BOOL_COND" == 1 ]]; then
	TRAIN_MODEL_PATH=$TRAIN_MODEL_PATH"/"
fi

check_zero_file $SOURCE_TRAIN_FILE
check_zero_file $TARGET_TRAIN_FILE
check_zero_file $SOURCE_DEV_FILE
check_zero_file $TARGET_DEV_FILE
check_equal_lines "$SOURCE_TRAIN_FILE" "$TARGET_TRAIN_FILE"
check_equal_lines "$SOURCE_DEV_FILE" "$TARGET_DEV_FILE"
check_location_exists "$TRAIN_MODEL_PATH"
check_bool "$TRAIN_PARENT_MODEL" 

if [[ -n "$PARENT_MODEL_PATH" ]]
then
	check_relative_path "$PARENT_MODEL_PATH"
	check_dir_final_char "$PARENT_MODEL_PATH"
	BOOL_COND=$?
	if [[ "$BOOL_COND" == 1 ]]; then
		PARENT_MODEL_PATH=$PARENT_MODEL_PATH"/"
	fi
	check_parent_structure "$PARENT_MODEL_PATH"		
fi

if [[ "$TRAIN_PARENT_MODEL" == "1" ]]; then
	check_relative_path $MAPPING_SOURCE
	check_relative_path $MAPPING_TARGET
	check_zero_file $MAPPING_SOURCE
	check_zero_file $MAPPING_TARGET
fi

create_new_dir "$TRAIN_MODEL_PATH" "$PARENT_MODEL_PATH"

### Path to executables ###
RNN_LOCATION="${DIR}/helper_programs/RNN_MODEL"
PRETRAIN_LOCATION="${DIR}/helper_programs/pretrain.pl"
SMART_QSUB="${DIR}/helper_programs/qsubrun"
TRAIN_SINGLE_NORMAL="${DIR}/helper_programs/train_single_model.sh"
TRAIN_SINGLE_PREINIT="${DIR}/helper_programs/train_preinit_model.sh"
CREATE_MAPPING_PURE="${DIR}/helper_programs/create_mapping_pureNMT.py"
CREATE_MAPPING_PARENT="${DIR}/helper_programs/create_mapping_parent.py"

### Check if doing preinitialization and if so launch the models  ###
if [[ -n "$PARENT_MODEL_PATH" ]]
then
	for i in $( seq 1 8 )
	do
		$SMART_QSUB $TRAIN_SINGLE_PREINIT $SOURCE_TRAIN_FILE $TARGET_TRAIN_FILE $TRAIN_MODEL_PATH"/model$i" $SOURCE_DEV_FILE $TARGET_DEV_FILE $PRETRAIN_LOCATION 
	done
	exit 0
elif [[ "$TRAIN_PARENT_MODEL" == "0" ]]; then

	python $CREATE_MAPPING_PURE $SOURCE_TRAIN_FILE $TARGET_TRAIN_FILE "6" "$TRAIN_MODEL_PATH""count6.nn" 
else
	python $CREATE_MAPPING_PARENT $MAPPING_SOURCE $MAPPING_TARGET "6" "$TRAIN_MODEL_PATH""count6.nn" $SOURCE_TRAIN_FILE
fi


### Model settings ###

DROPOUT_SETTING1=""
DROPOUT_SETTING2=""
if [[ "$TRAIN_PARENT_MODEL" -eq "1" ]]
then
	DROPOUT_SETTING1="-d 0.8"
else
	DROPOUT_SETTING1="-d 0.5"
	DROPOUT_SETTING2="-d 0.5"
fi


MODEL_1_OPTS="\"-H 750 -N 2 $DROPOUT_SETTING1\""
MODEL_2_OPTS="\"-H 750 -N 3 $DROPOUT_SETTING1\""
MODEL_3_OPTS="\"-H 1000 -N 2 $DROPOUT_SETTING1\""
MODEL_4_OPTS="\"-H 1000 -N 3 $DROPOUT_SETTING1\""
MODEL_5_OPTS="\"-H 750 -N 2 $DROPOUT_SETTING2\""
MODEL_6_OPTS="\"-H 750 -N 3 $DROPOUT_SETTING2\""
MODEL_7_OPTS="\"-H 1000 -N 2 $DROPOUT_SETTING2\""
MODEL_8_OPTS="\"-H 1000 -N 3 $DROPOUT_SETTING2\""
SHARED_OPTS="\"-m 128 -l 0.5 -P -0.08 0.08 -w 5 --attention-model 1 --feed_input 1 --screen-print-rate 30 --HPC-output 1 -B best.nn -n 100 --random-seed 1 -L 100\""
GPU_OPTS_1="\"-M 0 1 1\""
GPU_OPTS_2="\"-M 0 0 1 1\""

for i in $( seq 1 8 )
do	
	TEMP="MODEL_${i}_OPTS"
	CURR_GPU_OPT=$GPU_OPTS_1
	if [[ $i -eq "2" ]] || [[ $i -eq "4" ]] || [[ $i -eq "6" ]] || [[ $i -eq "8" ]]
	then
		CURR_GPU_OPT=$GPU_OPTS_2
	fi
	$SMART_QSUB $TRAIN_SINGLE_NORMAL $SOURCE_TRAIN_FILE $TARGET_TRAIN_FILE $TRAIN_MODEL_PATH"model$i" $SOURCE_DEV_FILE $TARGET_DEV_FILE ${!TEMP} $CURR_GPU_OPT $SHARED_OPTS $RNN_LOCATION
done

exit 0