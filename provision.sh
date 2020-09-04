#!/bin/bash
#alias coreos-installer='podman run --pull=always            \
#                        --rm --tty --interactive            \
#                        --security-opt label=disable        \
#                        --volume ${PWD}:/pwd --workdir /pwd \
#                        quay.io/coreos/coreos-installer:release'
set -x

alias ignition-validate='podman run --rm --tty --interactive \
                         --security-opt label=disable        \
                         --volume ${PWD}:/pwd --workdir /pwd \
                         quay.io/coreos/ignition-validate:release'

alias fcct='podman run --rm --tty --interactive \
            --security-opt label=disable        \
            --volume ${PWD}:/pwd --workdir /pwd \
            quay.io/coreos/fcct:release'
yaml=_*.yml
 yml=$(echo $yaml | sed -E '/^_//')
config=${vm_name}.json
stream=next
serial=yes

export vm_name=kizul
source defs/setup_def.sh
echo $yml; exit
envsubst < $yaml > $yml
fcct --pretty --strict $yml --output $config

# https://unix.stackexchange.com/questions/150957/generating-file-with-ascii-numbers-using-dev-urandom
gcloud compute instances create --metadata-from-file "user-data=${config:-}" --image-project "fedora-coreos-cloud" --image-family "fedora-coreos-${stream:-}" "${vm_name:-}"
[ -n "${serial:-}" ] && gcloud compute instances add-metadata ${vm_name:-} --metadata serial-port-enable=TRUE
