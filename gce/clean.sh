#!/bin/bash

# A script to clean up a GitHub Actions runner instance.
# It's intended to be run daily via a cron job.

echo "Starting daily runner cleanup at $(date)"

# --- Clear the Docker system and unused images/volumes ---
# The 'prune' command removes unused containers, networks, images, and volumes.
echo "Cleaning up Docker system..."
sudo docker system prune --all --force --volumes

# --- Clear package manager caches ---
# This frees up space used by downloaded packages.
if command -v apt-get &> /dev/null
then
    echo "Cleaning up APT cache..."
    sudo apt-get clean
fi

# --- Remove temporary files ---
# This removes files from common temporary directories, but we'll exclude the runner's own temp files if possible.
echo "Cleaning up temporary files..."
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# --- Clean up the GitHub Actions runner cache ---
# This is a critical step for self-hosted runners.
# The `_actions` and `_temp` directories are where actions and artifacts are stored.
# The runner's current working directory is typically named with a long GUID string, so we'll target that.
echo "Cleaning up runner work directories..."
RUNNER_DIR="/runner-tmp" # Change this to your runner's home directory if different

if [ -d "$RUNNER_DIR" ]; then
  # Remove all subdirectories within the runner's work directory
  find "$RUNNER_DIR" -mindepth 1 -maxdepth 1 -exec sudo rm -rf {} +
fi

echo "Daily cleanup finished."
