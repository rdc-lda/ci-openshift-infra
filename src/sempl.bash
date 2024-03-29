#!/bin/bash

__sempl_path=$0
__sempl_version=0.3.0

__sempl_verbose=0
__sempl_stdout=0
__sempl_fail_missing=0
__sempl_check=0
__sempl_template=''
__sempl_outfile=''
__sempl_varsfiles=( )
__sempl_password=''
__sempl_password_file=''

_usage() {
  echo "usage: $0 [args] template [outfile]"
  echo
  echo "args:"
  echo "-s [varsfile]   vars file (can be repeated)"
  echo "-p [password]   decryption password"
  echo "-k [passfile]   decryption password file"
  echo "-v              verbose"
  echo "-o              print template to stdout"
  echo "-f              fail if a variable is unset with no default"
  echo "-c              check that the template will render, but do not write the file"
  echo "-h              help"
  echo "--version       print version and exit"
  echo "--update        update script to latest version"
  echo
}

_version() {
  echo "version ${__sempl_version}"
}

_verbose() {
  [ $__sempl_verbose -eq 1 ] && echo ${1}
}

_error() {
  echo "ERROR: ${1}"
  exit 1
}

_convert_template() {
  local __in_block=0
  local __tmp_script=/dev/null
  local __tmp_tmpl=$(mktemp -t sempl.XXXXXX)
  local __escaped_line=''
  while IFS='' read __line || [[ -n ${__line} ]]; do
    if echo "${__line}" | grep -E -q '^(\s+)?###(\s)?begin'; then
      __in_block=1
      __tmp_script=$(mktemp -t sempl.XXXXXX)
      continue
    fi
    if echo "${__line}" | grep -E -q '^(\s+)?###(\s)?end'; then
      __in_block=0
      bash $__tmp_script >> $__tmp_tmpl
      rm $__tmp_script
      continue
    fi
    if [ $__in_block -eq 1 ]; then
      if echo "${__line}" | grep -E -q '^(\s+)?#'; then
        echo "${__line}" | sed 's/#//1' >> $__tmp_script
      else
        __escaped_line=$(echo "${__line}" | sed 's/"/"\\\"/g')
        echo "echo \"${__escaped_line}\"" >> $__tmp_script
      fi
    else
      echo "${__line}" >> $__tmp_tmpl
    fi
  done < $__sempl_template
  if [ $__sempl_fail_missing -eq 1 ]; then
    set -o nounset
    set -o pipefail
  fi
  eval "echo \"$(cat ${__tmp_tmpl} \
                   | sed 's/\"/\"\\\"/g' \
                   | sed 's/</\\</g' \
                   | sed 's/>/\\>/g')\"" \
    | sed 's/\\>/>/g' \
    | sed 's/\\</</g' \
    > $__sempl_outfile
  local __rc=$?
  set +o nounset
  set +o pipefail
  rm $__tmp_tmpl
  if [ $__sempl_check -ne 1 ]; then
    if [ $__rc -eq 0 ]; then
      [[ $__sempl_outfile == '/dev/stdout' ]] || _verbose "Template written to ${__sempl_outfile}"
    else
      _error "Could not convert template ${__sempl_template}"
    fi
  fi
  return $__rc
}

_update() {
  local cmd=''
  which curl &> /dev/null && cmd="curl --silent -o ${__sempl_path}"
  which wget &> /dev/null && cmd="wget -q -O ${__sempl_path}"
  [ -z "$cmd" ] && _error "unable to find curl or wget in PATH"
  eval "$cmd https://raw.githubusercontent.com/nextrevision/sempl/master/sempl"
  local version=$(grep -E -m 1 '^__sempl_version=' $__sempl_path | cut -d'=' -f2)
  echo "Updated from ${__sempl_version} to ${version}"
}

_main() {
  [ -z "$1" ] && { _usage; exit 1; }

  while [ ! -z "$1" ]; do
    case "$1" in
      -s)        shift; __sempl_varsfiles[${#__sempl_varsfiles[@]}]=${1};;
      -p)        shift; __sempl_password=${1};;
      -k)        shift; __sempl_password_file=${1};;
      -v)        __sempl_verbose=1;;
      -o)        __sempl_stdout=1;;
      -f)        __sempl_fail_missing=1;;
      -c)        __sempl_check=1;;
      -h|--help) _usage; exit;;
      --version) _version; exit;;
      --update)  _update; exit;;
      *)         __sempl_template=${1};
                 shift; __sempl_outfile=${1};;
    esac
    shift
  done

  # ensure a template file was passed
  if [ -z "${__sempl_template}" ]; then
    _error "No template file supplied"
  fi

  # ensure read permissions to template file
  [ -r ${__sempl_template} ] || _error "No such template '${__sempl_template}'"

  if [ ! -z "${__sempl_password_file}" ]; then
    [ -r ${__sempl_password_file} ] || _error "Cannot read password file '${__sempl_password_file}'"
    __sempl_password=$(head -n1 ${__sempl_password_file})
  fi

  # if a vars file was specified ensure read permissions and load
  for varsfile in "${__sempl_varsfiles[@]}"; do
    if head -1 ${varsfile} | grep -q -e '^Salted_'; then
      if [ ! -z "${__sempl_password}" ]; then
        openssl aes-256-cbc -d -salt -in ${varsfile} -out ${varsfile}.unenc -k ${__sempl_password} \
          || { rm -f ${varsfile}.unenc; _error "Unable to decrypt password vars file ${varsfile}"; }
        source ${varsfile}.unenc \
          && rm -f ${varsfile}.unenc \
          || { rm -f ${varsfile}.unenc; _error "Cannot source vars file '${varsfile}'"; }
      else
        _error 'No decryption password specified'
      fi
    else
      source ${varsfile} || _error "Cannot source vars file '${varsfile}'"
    fi
  done

  # default outfile to template file without .tpml extension
  if [ -z "${__sempl_outfile}" ]; then
    __sempl_outfile=${__sempl_template//.tmpl/}
  fi
  if [ $__sempl_stdout -eq 1 ]; then
    __sempl_outfile=/dev/stdout
  fi
  if [ $__sempl_check -eq 1 ]; then
    __sempl_outfile=/dev/null
  fi

  # do work
  _convert_template
  return $?
}

# test if script is being called or sourced
if [[ $(basename ${0//-/}) == "sempl" ]]; then
  _main "$@"
fi