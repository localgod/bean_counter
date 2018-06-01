#!/usr/bin/env bash

# Search repository for occurence of string
# Save json formatted file with result.
function _scan () {
  local repo="$1"
  local search_string="$2"
  git clone --quiet --depth 1 "${repo}" ./tmp  > /dev/null

  if [[ "$(ls -A ./tmp)" == ".git" ]]; then
     echo "Empty. Moving on!"
  else
    cd ./tmp
    local filename=''
    if [[ "$(echo "${repo}" | awk -F  "/" '{print $1}')" == "ssh:" ]]
    then
      filename="$(echo "${repo}" | awk -F  "/" '{print $4 "_" $5 }')"
    else
      filename="$(echo "${repo}" | awk -F  "/" '{print $5 "_" $6 }')"
    fi

    filename="${filename/.git/.json}"

    local output="$(_search "${repo}" "${search_string}")"

    if [[ "${output}" != "" ]]
    then
      echo "${output}" > "../${filename}"
    fi
    cd ..
  fi
  rm -rf ./tmp
}

# Search repository for occurence of string
# Return json formatted list of files with lines matching
function _search () {
  local result=$(GREP_OPTIONS='' fgrep -n --color=never \
        --binary-files=without-match \
        -ri "${2}" . \
        | awk -F  ":" '{print substr($1,2) " " $2}')
  local envelope="$(jq -n --arg repo "${1}" '{"repo":$repo, "files" : []}')"
  local unique_files="$(echo "${result}" | awk '{print $1}' | uniq)"

  if [[ "${unique_files}" != "" ]]
  then
    local files=""
    while read -r line; do
      local lines=""
      while read -r linenumber; do
        if [[ "${lines}" == "" ]]
        then
          lines="$(echo "${linenumber}" | awk '{print $2}')"
        else
          lines="${lines},$(echo "${linenumber}" | awk '{print $2}')"
        fi
      done <<< "$(echo "${result}" | GREP_OPTIONS='' fgrep "${line}")"

      files="${files}\
            $(jq -n --arg file "${line}" --arg lines "${lines}" \
            '{"path":$file, "line" : $lines|split(",") | map(. | tonumber)}')"
    done <<< "${unique_files}"

    files="$(echo ${files} | jq -s -c -r '.')"

    echo "${envelope}" | jq --argjson files "${files}" '.files = $files'
  fi
}

# Script entrypoint
function main () {
  echo -e "Searching: $(wc -l "$1" | awk '{ print $1}') Repositories\n"
  while IFS='' read -r line || [[ -n "$line" ]]; do
      if [[ "${2}" == "" ]] ; then echo -e "Search cannot be empty"; exit 1;
      else
        _scan "${line}" "${2}"
        echo "${line}" >> ./progress.txt
      fi
  done < "$1"
  echo -e "Done\n"
}

main "$@"
