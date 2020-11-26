#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname $0)/.."

mkdir -p /tm
/cc/utils/cli.py config attribute --cfg-type kubernetes --cfg-name testmachinery --key kubeconfig > /tm/kubeconfig
/testrunner run \
    --tm-kubeconfig-path=/tm/kubeconfig \
    --no-execution-group \
    --testrun-prefix terraformer-pod-e2e- \
    --timeout=1800 \
    --testruns-chart-path=.ci/testruns/default \
    --set revision="$(cat ./VERSION)"
