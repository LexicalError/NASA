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
    cd "$target_dir"
    local list=($(find . -type f | LC_COLLATE=C sort))
    for dir_i in ${list[@]}; do
        if [[ (-h "$dir_i") || ("$dir_i" == "$1") || (-d "$dir_i") ]]; then
            continue
        elif [[ -f "$dir_i" ]]; then
            echo ${dir_i:2}
        fi
    done
}

H(){
    if [[ "$2" == "file" ]]; then 
        # sha256sum $1 | awk '{print $1}' | xxd -r -p 
        sha256sum $1 | awk '{print $1}' | tr -d '\n'
    else
        # Hex to binary first
        echo -n "$1" | xxd -r -p | sha256sum | awk '{print $1}' | tr -d '\n'
    fi
}

M(){
    local M_i=$1
    local M_j=$2
    local M_dir=$3
    if ((M_i == M_j)); then
        H "$M_dir/${p[$((M_i - 1))]}" "file"
    else
        local M_m=$((M_j - M_i + 1))
        # 2^a = e^(ln2)a
        local M_k=$(echo $M_m | awk 'function floor(x){return int(x) - (x < int(x))} {print exp(log(2) * floor(log($1 - 1) / log(2)))}')
        # Concatenate in hex to prevent losing null bytes
        hash1=$(M "$M_i" "$((M_k + M_i - 1))" "$M_dir")
        hash2=$(M "$((M_k + M_i))" "$((M_m + M_i - 1))" "$M_dir")
        H "$hash1""$hash2" "hash" 
    fi
}

build(){
    local target_dir=$1
    declare -g p=($(dir_walk "$target_dir"))
    local n=0
    for file in "${p[@]}"; do
        echo $file
        n=$((n+1))
    done
    echo ''
    local K=$(echo "$n" | awk 'function ceil(x){return int(x) + (x > int(x))} {print ceil(log($1) / log(2))}')
    for((k = 0; k <= K; k++)); do
        local N=$(echo "$n $k" | awk 'function floor(x){return int(x) - (x < int(x))} {print floor($1 / exp(log(2) * $2))}')
        for ((i = 1; i <= N; i++)); do
            local start="$(echo "$i $k" | awk '{print ($1 - 1) * exp(log(2) * $2) + 1}')"
            local end="$(echo "$i $k" | awk '{print $1 * exp(log(2) * $2)}')"
            M "$start" "$end" "$target_dir"
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
            if (( N > 0)); then
                echo -n ':'
            fi
            local start="$(echo "$N $k" | awk '{print $1 * exp(log(2) * $2) + 1}')"
            local end="$n"
            M "$start" "$end" "$target_dir"
            # M $start $end $target_dir
            echo ''
        fi
    done
}

pi(){
    local j=$1
    local s=$2
    local m=$3
    local k=$(echo $m | awk 'function floor(x){return int(x) - (x < int(x))} {print exp(log(2) * floor(log($1 - 1) / log(2)))}')
    if ((m == 1)); then
        echo -n ' '
    elif ((j <= k)); then
        #  M s+k s+m-1
        echo -n "$(pi "$j" "$s" "$k") ${hashes["$((s + k))" "$((s + m - 1))"]} "
    else
        # M s s+k-1
        echo -n "$(pi $((j - k)) $((s + k)) $((m - k))) ${hashes["$s $((s + k - 1))"]} "
    fi
}

gen-proof(){
    local leaf_file=$1
    local tree_file=$2
    local file_in_tree=0
    local leaf_index=0
    local n=0
    declare -g -A hashes
    # Read files
    while IFS='' read -r line; do
        if [[ $line == '' ]]; then
            break
        elif [[ "$line" == "$leaf_file" ]]; then
            file_in_tree=1
            leaf_index=$((n + 1))
        fi
        # echo "$line"
        n=$((n + 1))
    done < $tree_file

    # Leaf not found in tree file
    if (( file_in_tree == 0 )); then
        return 1
    fi

    # Read hashes
    local parsed_hashes=($(awk 'NF==0 {flag=1; next} flag{n=split($0,arr,":"); for (i=1; i<=n; i++) print(arr[i])}' $tree_file))
    local tmp_index=0
    local K=$(echo "$n" | awk 'function ceil(x){return int(x) + (x > int(x))} {print ceil(log($1) / log(2))}')
    for((k = 0; k <= K; k++)); do
        local N=$(echo "$n $k" | awk 'function floor(x){return int(x) - (x < int(x))} {print floor($1 / exp(log(2) * $2))}')
        for ((i = 1; i <= $N; i++)); do
            local start=$(echo "$i $k" | awk '{print ($1 - 1) * exp(log(2) * $2) + 1}')
            local end=$(echo "$i $k" | awk '{print $1 * exp(log(2) * $2)}')
            # M $start $end 
            hashes["$start $end"]="${parsed_hashes[$tmp_index]}"
            tmp_index=$((tmp_index+1))
        done
        if (( k == 0 )); then
            continue
        elif (( (n % (2**k)) <= (2**(k-1)) )); then
            continue
        else
            local start=$(echo "$N $k" | awk '{print $1 * exp(log(2) * $2) + 1}')
            local end=$n
            # M $start $end 
            hashes["$start $end"]="${parsed_hashes[$tmp_index]}"
            tmp_index=$((tmp_index+1))
        fi
    done

    echo "leaf_index:$leaf_index,tree_size:$n"
    # local proof=($(pi "$leaf_index" "1" "$n")) 
    local proof=() 
    local j="$leaf_index"
    local s="1"
    local m="$n"
    local k=0
    while true; do
        k=$(echo $m | awk 'function floor(x){return int(x) - (x < int(x))} {print exp(log(2) * floor(log($1 - 1) / log(2)))}')
        if ((m == 1)); then
            break;
        elif ((j <= k)); then
            # pi j s k -||- hashes s+k s+m-1
            proof+=(${hashes["$((s + k)) $((s + m - 1))"]})
            m="$k"
        else
            # M s s+k-1
            # pi j-k s+k m-k -||- hashes[s s+k-1]} "
            proof+=(${hashes["$s $((s + k - 1))"]})
            j=$((j - k))
            s=$((s + k))
            m=$((m - k))
        fi
    done 
    for ((index=${#proof[@]} - 1; index >= 0; index--)); do
        echo "${proof[$index]}"
    done
}

verify-proof(){
    local f=$1
    local proof_file=$2
    local root_hash=$3
    local k=$(head -n 1 "$proof_file" | awk -F '[:,]' '{ print $2 }' )
    local n=$(head -n 1 "$proof_file" | awk -F '[:,]' '{ print $4 }' )
    local pi_p=($(tail -n +2 "$proof_file"))
    local m=${#pi_p[@]}

    local k_p=$((k-1))
    local n_p=$((n-1))
    local h=$(H "$f" "file")

    for ((i = 1; i <= m; i++)); do
        if ((n_p == 0)); then
            return 1
        fi
        if (( ((k_p & 1) == 1) || (k_p == n_p) )); then
            h=$(H "${pi_p[$((i - 1))]}""$h" "hash")
            while (( (k_p & 1) == 0 )); do
                k_p=$((k_p >> 1))
                n_p=$((n_p >> 1))
            done
        else
            h=$(H "$h""${pi_p[$((i - 1))]}" "hash")
        fi
        k_p=$((k_p >> 1))
        n_p=$((n_p >> 1))
    done
    if [[ ($n_p -eq 0) && ("$h" == "$root_hash") ]]; then
        return 0
    else
        return 1
    fi
}

if [[ ("$subcmd" == "build") && ("$out_flag$tree_flag$proof_flag$hash_flag$arg_flag" == "10001") && (((! -e "$output_file") || (-f "$output_file")) && (-d "$argument")) && (! -h "$output_file") && (! -h "$argument") ]]; then
    build $argument > $output_file
elif [[ ("$subcmd" == "gen-proof") && ("$out_flag$tree_flag$proof_flag$hash_flag$arg_flag" == "11001") && (((! -e "$output_file") || (-f "$output_file")) && (-f "$tree_file")) && (! -h "$output_file") && (! -h "$tree_file") ]]; then
    gen-proof $argument $tree_file > $output_file
    if (( $? == 1 )); then
        echo 'ERROR: file not found in tree'
        exit 1
    fi
elif [[ ("$subcmd" == "verify-proof") && ("$out_flag$tree_flag$proof_flag$hash_flag$arg_flag" == "00111") && ((-f "$proof_file") && (( ! "$hash" =~ [^0-9A-F]+) || (! "$hash" =~ [^0-9a-f]+)) && (-f "$argument")) && (! -h "$proof_file") && (! -h "$argument")]]; then
    # Convert upper to lower
    hash=$(echo "$hash" | awk '{print tolower($0)}')
    verify-proof $argument $proof_file $hash
    if (( $? == 0 )); then
        echo 'OK'
        exit 0
    else
        echo 'Verification Failed'
        exit 1
    fi
else
    usage
    exit 1
fi