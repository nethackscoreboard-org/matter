#!/usr/bin/env zsh
#alias coreos-installer='podman run --pull=always            \
#                        --rm --tty --interactive            \
#                        --security-opt label=disable        \
#                        --volume ${PWD}:/pwd --workdir /pwd \
#                        quay.io/coreos/coreos-installer:release'
export yaml=docker-cg1.yml
export vm_name=kizul
export config=${vm_name}.json
export stream=stable
export serial=yes
export domain=gcloud.ext

alias ignition-validate='podman run --rm --tty --interactive \
                         --security-opt label=disable        \
                         --volume ${PWD}:/pwd --workdir /pwd \
                         quay.io/coreos/ignition-validate:release'

alias fcct='podman run --rm --tty --interactive --security-opt \
            label=disable --volume ${PWD}:/pwd --workdir /pwd \
            quay.io/coreos/fcct:release'

# --kill
if [[ $# -eq 1 ]] && [[ "$1" == "--kill" ]]; then
    gcloud compute instances delete $vm_name
    grep -v "^$vm_name" ~/.ssh/known_hosts >~/.ssh/known_hosts-
    grep -v "$vm_name" /etc/hosts >~/.ssh/hosts
fi


fcct --pretty --strict $yaml --output $config

# https://unix.stackexchange.com/questions/150957/generating-file-with-ascii-numbers-using-dev-urandom
ip=$(gcloud compute instances create --metadata-from-file "user-data=${config:-}" --image-project "fedora-coreos-cloud" --image-family "fedora-coreos-${stream:-}" "${vm_name:-}" | grep -E "^$vm_name" | sed -E 's/[[:space:]]+/ /g' | cut -d' ' -f5)

# update stuff
vm_full=${vm_name}.${domain}
echo $ip    $vm_full    $vm_name | tee -a ~/.ssh/hosts
sudo cp ~/.ssh/hosts /etc/hosts
mv ~/.ssh/known_hosts- ~/.ssh/known_hosts


[ -n "${serial:-}" ] && gcloud compute instances add-metadata ${vm_name:-} --metadata serial-port-enable=TRUE
