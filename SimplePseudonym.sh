#!/bin/bash
SEP=","
PSEUDONYMS="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/pseudonyms.csv"

function getRandom() {
	echo "$(dd if=/dev/urandom bs=1M count=1 status=none | sha1sum | grep -oE '^\w+')"
}

function _pseudomize() {
	if [ ! -f "$PSEUDONYMS" ]; then
		touch "$PSEUDONYMS"
	fi
	(
		flock 42
		PSN="$(grep -oP '(?<=^'"$1$SEP"')\w+$' "$PSEUDONYMS")"
		if [ $? -gt 0 ]; then
			PSN="$(getRandom)"
			grep -qP '^\w+(?='"$SEP$PSN"'$)' "$PSEUDONYMS"
			while [ $? -eq 0 ]; do
				PSN="$(getRandom)"
				grep -qP '^\w+(?='"$SEP$PSN"'$)' "$PSEUDONYMS"
			done;
			echo "$1$SEP$PSN" >> pseudonyms.csv
		fi
		echo "$PSN"
	) 42<"$PSEUDONYMS"
}

function _depseudomize() {
	if [ ! -f "$PSEUDONYMS" ]; then
		touch "$PSEUDONYMS"
	fi
	grep -oP '^\w+(?='"$SEP$1"'$)' "$PSEUDONYMS" || echo "UNKOWN PSEUDONYM: $1"
}

function pseudomize() {
	case $1 in
		-)
			while read line; do
				_pseudomize "$line"
			done </dev/stdin ;;
		*)
			_pseudomize "$1" ;;
	esac
}

function depseudomize() {
	case $1 in
		-)
			while read line; do
				_depseudomize "$line"
			done </dev/stdin ;;
		*)
			_depseudomize "$1" ;;
	esac
}

TEMP=`getopt -o hp:d: --long help,pseudomize:,depseudomize: -n "$(basename "$BASH_SOURCE")" -- "${@}"`

if [ $? != 0 ] ; then exit 1 ; fi

eval set -- "${TEMP}";

while [[ ${1:0:1} = - ]]; do
	case $1 in
		-h|--help)
			cat <<EOF
$(basename "$BASH_SOURCE") translates identifier to random pseudonyms and reverse.

USAGE: $(basename "$BASH_SOURCE") [OPTIONS]

OPTIONS

  -h --help		Print this help
  -p --pseudomize	Get pseudonym for identifier (use -p- to read list from STDIN)
  -d --depseudomize	Get identifier for pseudonym (use -d- to read list from STDIN)

EOF
        							shift 1; exit ;;
		--)						shift 1; break ;;
		-p|--pseudomize)	pseudomize "$2";	shift 2; continue ;;
		-d|--depseudomize)	depseudomize "$2";	shift 2; continue ;;
	esac

	echo "ERROR: Unknown parameter ${1}"
	exit;
done

