#!/usr/bin/env bash

function git_checkout () {
  local repo="$1"
  local search_string="$2"
  #git clone "${repo}" ./tmp
  cd ./tmp
  filename="${repo/https:\/\//}"
  filename="${filename/.git/}"
  filename="${filename/./_}"
  filename="${filename//\//_}"
  local output="$(_search "${repo}" "${search_string}")"

  if [[ "${output}" != "" ]]
  then
    echo "${output}" > "../${filename}.json"
  fi
  cd ..
  #rm -rf ./tmp
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

git_checkout $@ 
