#!/bin/bash
usage(){
    echo 'Usage: ./Combine-Html --input [input file] --output [output file]'
    exit 1
}

TEMP=$(getopt -o "i:o:" -l "input:,output:" -n "$0" --  "$@")
eval set -- "$TEMP"


while true; do
  case "$1" in
    --input)
      input_file="$2"
      shift 2
      ;;
    --output) 
      output_file="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      usage
      ;;
  esac
done

if [[ ! -e $output_file ]]; then
    touch $output_file
    if [[ $? -ne 0 ]]; then
        usage
    fi
fi

if [[ (! -f $input_file) || (! -r $input_file) || (! -f $output_file) || (! -w $output_file) ]]; then
    usage
fi


comb(){
    export -f comb
    type=${1##*.}
    path="${1%/*}"
    file=${1##*/}
    # echo $(pwd) 
    # echo $path
    # echo $file"|"$type
    if [[ ! "$path" == "$1" ]]; then 
        cd $path
    fi
     

    if [[ (! -e $file) || (! -f $file) || (! -r $file) ]]; then
        echo -n "<p style=\"color:red;\">Cannot access $1</p>"
    
    elif [[ ("$type" == "jpg") || ("$type" == "png") ]]; then
        echo -n "<img src=\"data:image/$type;base64,$(base64 -w0 $file)\" />"
    else 
    sed -E ':x; s/(.*)(<include src=")([[:alnum:]_/\.]+)(" \/>)(.*)/echo -n '"\'\1\'"' \; comb \3 \; echo -n '"\'\5\'/"'eg; tx' $file | sed -ze 's/\n$//' 
    fi 
}


comb $input_file > $output_file

