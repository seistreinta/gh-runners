#!/bin/bash
# Builder provisioning script for the BAKED GitHub runner image.
# Runs once, as the startup-script of a throwaway `runner-image-builder` VM.
# It pre-installs everything STATIC (apt deps, docker, the runner binaries, and the
# daily cleanup cron) so the runtime startup-script (startup-baked.sh) only has to
# fetch secrets + register. Does NOT configure/register a runner (token is ephemeral).
#
# Completion is signalled on the serial console with BUILDER_PROVISIONING_COMPLETE.

echo "=== builder provisioning start ==="

# --- static apt deps ---
apt-get update
apt-get -y install jq docker.io nano
# libicu74 is the ICU package on Ubuntu 24.04 (noble); pre-installing it stops the
# 'Unable to locate package libicu72/71/67' warnings from installdependencies.sh.
apt-get -y install libicu74

# --- GitHub Actions runner binaries (baked, not configured) ---
# Track GitHub's current latest so fresh VMs don't auto-update on first boot.
export GH_RUNNER_VERSION="2.335.1"
mkdir -p /runner /runner-tmp
curl -o /tmp/actions.tar.gz --location "https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz"
tar -zxf /tmp/actions.tar.gz --directory /runner
rm -f /tmp/actions.tar.gz
/runner/bin/installdependencies.sh

# --- bake the daily cleanup script + 3AM cron (same behaviour as startup.sh) ---
cat << 'EOF' > /usr/local/bin/runner_cleanup.sh
#!/bin/bash
RUNNER_DIR="/runner-tmp"
echo "Starting daily runner cleanup at $(date)"
sudo docker system prune --all --force --volumes
if command -v apt-get &> /dev/null; then
    sudo apt-get clean
fi
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
if [ -d "$RUNNER_DIR" ]; then
  find "$RUNNER_DIR" -mindepth 1 -maxdepth 1 -exec sudo rm -rf {} +
fi
echo "Daily cleanup finished."
EOF
chmod +x /usr/local/bin/runner_cleanup.sh
(crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/runner_cleanup.sh >> /var/log/runner_cleanup.log 2>&1") | crontab -

# --- success criterion + image hygiene ---
if [ -x /runner/config.sh ] && [ -x /usr/local/bin/runner_cleanup.sh ]; then
  # so the captured image regenerates machine-id / ssh host keys on first boot
  cloud-init clean || true
  echo "BUILDER_PROVISIONING_COMPLETE"
else
  echo "BUILDER_PROVISIONING_FAILED: /runner/config.sh or cleanup script missing"
fi
