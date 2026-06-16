#!/bin/bash
# Runtime startup-script for the BAKED GitHub runner image.
# All static deps (docker, jq, runner binaries at /runner, daily cleanup cron) are
# pre-baked into the image by builder-provision.sh, so this only:
#   1. pulls runner-secret (GITHUB_TOKEN, REPO_OWNER, REPO_URL),
#   2. mints an org registration token and configures the runner,
#   3. installs + starts the runner service.
# This is gce/startup.sh minus the apt-install / download / installdependencies block.

# access secret from secretsmanager
echo "Setting secrets..."
secrets=$(gcloud secrets versions access latest --secret="runner-secret")
# set secrets as env vars
# shellcheck disable=SC2206
secretsConfig=($secrets)
for var in "${secretsConfig[@]}"; do
export "${var?}"
done

# get actions token
# shellcheck disable=SC2034
# ACTIONS_RUNNER_INPUT_NAME is used by config.sh
ACTIONS_RUNNER_INPUT_NAME=$HOSTNAME
ACTIONS_RUNNER_INPUT_TOKEN="$(curl -sS --request POST --url "https://api.github.com/orgs/${REPO_OWNER}/actions/runners/registration-token" --header "authorization: Bearer ${GITHUB_TOKEN}"  --header 'content-type: application/json' | jq -r .token)"
# configure runner
RUNNER_ALLOW_RUNASROOT=1 /runner/config.sh --unattended --replace --work "/runner-tmp" --url "$REPO_URL" --token "$ACTIONS_RUNNER_INPUT_TOKEN" --labels gce-runner
# install and start runner service
cd /runner || exit
./svc.sh install
./svc.sh start

echo "Baked-runner startup finished."
