#!/bin/bash

usage(){
    echo '''merkle-dir.sh - A tool for working with Merkle trees of directories.

Usage:
  merkle-dir.sh <subcommand> [options] [<argument>]
  merkle-dir.sh build <directory> --output <merkle-tree-file>
  merkle-dir.sh gen-proof <path-to-leaf-file> --tree <merkle-tree-file> --output <proof-file>
  merkle-dir.sh verify-proof <path-to-leaf-file> --proof <proof-file> --root <root-hash>

Subcommands:
  build          Construct a Merkle tree from a directory (requires --output).
  gen-proof      Generate a proof for a specific file in the Merkle tree (requires --tree and --output).
  verify-proof   Verify a proof against a Merkle root (requires --proof and --root).

Options:
  -h, --help     Show this help message and exit.
  --output FILE  Specify an output file (required for build and gen-proof).
  --tree FILE    Specify the Merkle tree file (required for gen-proof).
  --proof FILE   Specify the proof file (required for verify-proof).
  --root HASH    Specify the expected Merkle root hash (required for verify-proof).

Examples:
  merkle-dir.sh build dir1 --output dir1.mktree
  merkle-dir.sh gen-proof file1.txt --tree dir1.mktree --output file1.proof
  merkle-dir.sh verify-proof dir1/file1.txt --proof file1.proof --root abc123def456'''
}

subcmd=$1
shift 1

if [[ ("$subcmd" != "build") && ("$subcmd" != "gen-proof") && ("$subcmd" != "verify-proof")]]; then
    usage
    if [[ ("$#" -eq "0") && (("$subcmd" == "-h") || ("$subcmd" == "--help")) ]]; then
        exit 0
    else
        exit 1
    fi
fi

for arg in "$@"; do
    if [[ "$arg" == *=* ]]; then
        usage
        exit 1
    fi
done

TEMP=$(getopt -q -o "h:" -l "help,output:,tree:,proof:,root:" -n "$0" --  "$@")
eval set -- "$TEMP"

arg_flag=0
out_flag=0
tree_flag=0
proof_flag=0
hash_flag=0

while (($# > 0)); do
    case "$1" in
        -h | --help)
            exit 1 
            ;;
        --output) 
            output_file="$2"
            out_flag=1 
            shift 2
            ;;
        --tree) 
            tree_file="$2"
            tree_flag=1 
            shift 2
            ;;
        --proof) 
            proof_file="$2"
            proof_flag=1 
            shift 2
            ;;
        --root) 
            hash="$2"
            hash_flag=1
            shift 2
            ;;
        --)
            if (( ($# > 2) || ($# < 2) )); then
                usage
                exit 1
            fi
            argument="$2"
            arg_flag=1
            break
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

dir_walk(){

    for i in "$1"/* "$1"/.*; do
        if [[ -h $i ]]; then
            continue
        elif [[ -d $i ]]; then
            export -f dir_walk
            dir_walk $i 
        elif [[ -f $i ]]; then
            echo ${i:2}
        fi
    done
}

H(){
    if [[ "$2" == "file" ]]; then 
        sha256sum $1 | awk '{print $1}' | xxd -r -p 
    else
        echo -n "$1" | sha256sum | awk '{print $1}' | xxd -r -p 
    fi
}

hex(){
    echo -n "$1" | xxd -p -c 0 | sed -ze 's/\n$//g'
}

M(){
    i=$1
    j=$2
    dir=$3
    if ((i == j)); then
        H "$dir/${p[$((i - 1))]}" "file"
    else
        m=$((j - i + 1))
        # 2^a = e^(ln2)a
        k=$(echo $m | awk 'function floor(x){return int(x) - (x < int(x))} {print exp(log(2) * floor(log($1 - 1) / log(2)))}')
        hash1=$(M $i $((k + i - 1)) $dir)
        hash2=$(M $((k + i)) $((m + i - 1)) $dir)
        H "$hash1""$hash2" "hash" 
    fi
}

build(){
    prev_dir=$(pwd)
    target_dir=$1
    cd $target_dir
    declare -g p=($(dir_walk .))
    cd $prev_dir
    n=0
    for i in "${p[@]}"; do
        echo $i
        n=$((n+1))
    done
    echo ''
    K=$(echo "$n" | awk 'function ceil(x){return int(x) + (x > int(x))} {print ceil(log($1) / log(2))}')
    for((k = 0; k <= K; k++)); do
        N=$(echo "$n $k" | awk 'function floor(x){return int(x) - (x < int(x))} {print floor($1 / exp(log(2) * $2))}')
        for ((i = 1; i <= $N; i++)); do
            start=$(echo "$i $k" | awk '{print ($1 - 1) * exp(log(2) * $2) + 1}')
            end=$(echo "$i $k" | awk '{print $1 * exp(log(2) * $2)}')
            hex "$(M $start $end $target_dir)"
            # M $start $end $target_dir
            if ((i < N)); then
                echo -n ':'
            fi
        done
        if (( k == 0 )); then
            echo ''
        elif (( (n % (2**k)) <= (2**(k-1)) )); then
            echo ''
        else
            if (( $N > 0)); then
                echo -n ':'
            fi
            start=$(echo "$N $k" | awk '{print $1 * exp(log(2) * $2) + 1}')
            end=$n
            hex "$(M $start $end $target_dir)"
            # M $start $end $target_dir
            echo ''
        fi
    done
}

pi(){
    i=$1
    s=$2
    m=$3
    dir=$4
    k=$(echo $m | awk 'function floor(x){return int(x) - (x < int(x))} {print exp(log(2) * floor(log($1 - 1) / log(2)))}')
    if (($m == 1)); then
        echo -n ' '
    elif ((j <= k)); then
        echo -n "$(pi $j $s $k $dir) $(M $((s + k)) $((s + m - 1)) $dir) "
    else
        echo -n "$(pi $((j - k)) $((s + k)) $((m - k)) $dir) $(M $s $((s + k - 1)) $dir) "
    fi

}

gen-proof(){
    return 0
    leaf_file=$1
    tree_file=$2
    file_in_tree=0
    leaf_index=0
    n=0
    tmp_k=0
    declare -g p=()
    declare -g -A hashes
    while IFS='' read -r line; do
        if [[ $line == '' ]]; then
            # Read hashes
            K=$(echo "$n" | awk 'function ceil(x){return int(x) + (x > int(x))} {print ceil(log($1) / log(2))}')
            for((k = 1; k <= K; k++)); do
                N=$(echo "$n $k" | awk 'function floor(x){return int(x) - (x < int(x))} {print floor($1 / exp(log(2) * $2))}')
                for ((i = 1; i <= $N; i++)); do
                    start=$(echo "$i $k" | awk '{print ($1 - 1) * exp(log(2) * $2) + 1}')
                    end=$(echo "$i $k" | awk '{print $1 * exp(log(2) * $2)}')
                    hex "$(M $start $end $target_dir)"
                    # M $start $end $target_dir
                    if ((i < N)); then
                        echo -n ':'
                    fi
                done
                if (( k == 0 )); then
                    echo ''
                elif (( (n % (2**k)) <= (2**(k-1)) )); then
                    echo ''
                else
                    if (( $N > 0)); then
                        echo -n ':'
                    fi
                    start=$(echo "$N $k" | awk '{print $1 * exp(log(2) * $2) + 1}')
                    end=$n
                    hex "$(M $start $end $target_dir)"
                    # M $start $end $target_dir
                    echo ''
                fi
            done
        elif [[ "$line" == "$leaf_file" ]]; then
            file_in_tree=1
            i=$((n + 1))
        fi
        echo "$line"
        p+=("$line")
        n=$((n + 1))
    done < $tree_file
    if (( $file_in_tree == 0 )); then
        echo 'ERROR: file not found in tree'
        exit 1
    else
        echo "leaf_index:$i,tree_size:$n"
        pi "$leaf_index" "1" "$n" 
    fi
}

verify-proof(){
    echo "verify-proof"
}

# TO BE FIXED
if [[ ("$subcmd" == "build") && ("$out_flag$tree_flag$proof_flag$hash_flag$arg_flag" == "10001") && (((! -e "$output_file") || (-f "$output_file")) && (-d "$argument")) && (! -h "$output_file") && (! -h "$argument") ]]; then
    build $argument > $output_file
elif [[ ("$subcmd" == "gen-proof") && ("$out_flag$tree_flag$proof_flag$hash_flag$arg_flag" == "11001") && (((! -e "$output_file") || (-f "$output_file")) && (-f "$tree_file")) && (! -h "$output_file") && (! -h "$tree_file") ]]; then
    gen-proof $argument $tree_file  $output_file
elif [[ ("$subcmd" == "verify-proof") && ("$out_flag$tree_flag$proof_flag$hash_flag$arg_flag" == "00111") && ((-f "$proof_file") && (( ! "$hash" =~ [^0-9A-F]+) || (! "$hash" =~ [^0-9a-f]+)) && (-f "$argument")) && (! -h "$proof_file") && (! -h "$argument")]]; then
    verify-proof 
else
    usage
    exit 1
fi


