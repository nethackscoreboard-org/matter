#!/usr/bin/env zsh
#alias coreos-installer='podman run --pull=always            \
#                        --rm --tty --interactive            \
#                        --security-opt label=disable        \
#                        --volume ${PWD}:/pwd --workdir /pwd \
#                        quay.io/coreos/coreos-installer:release'
set -x

export yaml=docker-cg1.yml
export vm_name=kizul
export config=${vm_name}.json
export stream=next
export serial=yes

alias ignition-validate='podman run --rm --tty --interactive \
                         --security-opt label=disable        \
                         --volume ${PWD}:/pwd --workdir /pwd \
                         quay.io/coreos/ignition-validate:release'

alias fcct='podman run --rm --tty --interactive --security-opt \
            label=disable --volume ${PWD}:/pwd --workdir /pwd \
            quay.io/coreos/fcct:release'


fcct --pretty --strict $yaml --output $config

# https://unix.stackexchange.com/questions/150957/generating-file-with-ascii-numbers-using-dev-urandom
gcloud compute instances create --metadata-from-file "user-data=${config:-}" --image-project "fedora-coreos-cloud" --image-family "fedora-coreos-${stream:-}" "${vm_name:-}"
[ -n "${serial:-}" ] && gcloud compute instances add-metadata ${vm_name:-} --metadata serial-port-enable=TRUE
