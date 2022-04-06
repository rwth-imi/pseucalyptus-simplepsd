#!/bin/sh
pid="SimplePseudonymReverse"
clientId="SimplePseudonymReverse_01"
clientDomain="SimplePseudonymReverse"
accessableBy=""

function worker() {
	transactionId="$(echo "$1" | sed -nr 's/.*"transactionId":"([^"]+)".*/\1/p')"
	processId="$(echo "$1" | sed -nr 's/.*"processId":"([^"]+)".*/\1/p')"
	fileId="$(echo "$1" | sed -nr 's/.*"fileId":"([^"]+)".*/\1/p')"
	timestamp="$(echo "$1" | sed -nr 's/.*"createdAt":"([^"]+)".*/\1/p')"
	if [ -z "$transactionId" ] || [ -z "$processId" ] || [ -z "$fileId" ]; then return; fi
	echo "$transactionId $processId $fileId $timestamp"
	curl --silent -X POST -H "x-client-id: $clientId" -H "x-client-domain: $clientDomain" "http://localhost:3000/v1/transactions/$transactionId/processes/$pid"
	curl --silent -X POST -H "x-client-id: $clientId" -H "x-client-domain: $clientDomain" -H "x-accessable-by: $accessableBy" -H 'Content-Type: text/csv' --data-binary @<(curl --silent -X GET -H "x-client-id: $clientId" -H "x-client-domain: $clientDomain" "http://localhost:3000/v1/transactions/$transactionId/processes/$processId/files/$fileId" | ./SimplePseudonym.sh -d-) "http://localhost:3000/v1/transactions/$transactionId/processes/$pid/files/$fileId"
}

inbox="$(curl --silent -X GET -H "x-client-id: $clientId" -H "x-client-domain: $clientDomain" "http://localhost:3000/v1/files/?filterUnprocessed=$pid")"
wssince="$(echo "$inbox" | sed -nE '/\n\n/q;s/^Date: (.+)$/\1/p')"

delim="},{"
data="$(echo "$inbox" | sed -E 'N;/\n\n/q;D')$delim"
while [[ $data ]]; do
	file="${data%%"$delim"*}"
	data="${data#*"$delim"}"
	worker "$file"
done

websocat --text --header="x-client-id: $clientId" --header="x-client-domain: $clientDomain" --header="Date: $wssince" - ws://localhost:3000/v1/files | \
while IFS= read file; do
	worker "$file"
done

