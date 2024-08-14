# Self Hosted Runners on GCE Managed Instance Groups with ADC

## Overview

This example showcases how to deploy GitHub Actions Self Hosted Runners on MIGs with Application Default Credentials.

## Steps to deploy this example

- Step 1: Set the required environment variables.

```sh
$ export PROJECT_ID=devops
$ export GITHUB_TOKEN=foo
$ export REPO_OWNER=seistreinta
$ export REPO_NAME=tepache-backend-framework
$ export REPO_URL=https://github.com/seistreinta
```

- Step 2: Enable the required GCP APIs.

```sh
$ gcloud config set project $PROJECT_ID
$ gcloud services enable compute.googleapis.com secretmanager.googleapis.com
```

- Step 3: Store the runner credentials as a secret.

```sh
$ gcloud secrets create runner-secret --replication-policy="automatic"
$ cat << EOF | gcloud secrets versions add runner-secret --data-file=-
REPO_NAME=${REPO_NAME}
REPO_OWNER=${REPO_OWNER}
GITHUB_TOKEN=${GITHUB_TOKEN}
REPO_URL=${REPO_URL}
EOF
```

- Step 4: Create a Service Account to be used by GCP VMs and allow it to access the runner secret.

```sh
$ gcloud iam service-accounts create gce-runner-sa --display-name "gce-runner-sa"
$ SA_EMAIL=$(gcloud iam service-accounts list --filter="displayName:gce-runner-sa" --format='value(email)')
$ gcloud secrets add-iam-policy-binding runner-secret \
    --member serviceAccount:$SA_EMAIL \
    --role roles/secretmanager.secretAccessor
```

- Step 5: Create an instance template and use it to create the MIG.

```sh
$ gcloud compute instance-templates create gh-runner-template \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-type=pd-standard \
    --boot-disk-size=10GB \
    --machine-type=n2d-standard-2 \
    --provisioning-model=SPOT \
    --instance-termination-action=STOP \
    --restart-on-failure \
    --scopes=cloud-platform \
    --service-account=$SA_EMAIL \
    --metadata-from-file=startup-script=startup.sh,shutdown-script=shutdown.sh
$ gcloud compute instance-groups managed create runner-group \
    --size=1 \
    --base-instance-name=gce-runner \
    --template=gh-runner-template \
    --zone=us-central1-f \
    --update-policy-minimal-action=restart \
    --update-policy-most-disruptive-action=replace \
    --update-policy-replacement-method=substitute \
    --update-policy-type=proactive
```
