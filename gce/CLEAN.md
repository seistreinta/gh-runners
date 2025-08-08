A daily cleanup script is an effective way to maintain a self-hosted GitHub Actions runner. You can set it up to run automatically using a cron job, a standard Linux task scheduler.

Here is a simple and safe cleanup script that you can use. It targets common areas where temporary files and caches accumulate.

-----

### 1\. Create the Cleanup Script

First, create a new file for the script. You can name it `runner_cleanup.sh` and place it in a location like `/usr/local/bin/`.

```bash
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
RUNNER_DIR="/home/github-runner/actions-runner/_work" # Change this to your runner's home directory if different

if [ -d "$RUNNER_DIR" ]; then
  # Remove all subdirectories within the runner's work directory
  find "$RUNNER_DIR" -mindepth 1 -maxdepth 1 -exec sudo rm -rf {} +
fi

echo "Daily cleanup finished."
```

Make sure to **change the `RUNNER_DIR` path** in the script to match the actual location of your GitHub runner's installation. The default is often a `_work` directory within the runner's root folder.

After creating the file, make it executable:

```bash
sudo chmod +x /usr/local/bin/runner_cleanup.sh
```

-----

### 2\. Schedule the Script with Cron

The next step is to schedule this script to run automatically every day. The `crontab` utility is perfect for this.

**Open the cron tab for editing:**

```bash
sudo crontab -e
```

This will open the cron configuration file in your default text editor.

**Add the daily job:**
Add the following line to the end of the file to run your script every day at 3:00 AM. ⏰

```
0 3 * * * /usr/local/bin/runner_cleanup.sh >> /var/log/runner_cleanup.log 2>&1
```

  * **`0 3 * * *`**: This is the cron schedule. It means:
      * `0`: at minute 0
      * `3`: at hour 3 (3:00 AM)
      * `*`: every day of the month
      * `*`: every month
      * `*`: every day of the week
  * **`/usr/local/bin/runner_cleanup.sh`**: The full path to your script.
  * **`>> /var/log/runner_cleanup.log 2>&1`**: This part redirects the script's output (both standard output and errors) to a log file. This is crucial for troubleshooting and making sure the cleanup is actually running.

Save and close the file. Cron will now automatically run your script daily at the specified time.



-------------------------------------------------------------------------------------------------------



Using `ubuntu-minimal-24.04-lts-amd64` has a few key considerations for creating and editing files, mainly because it's designed to be **lightweight** and **headless**. This means it might not include some of the user-friendly tools you're used to on a full desktop OS.

### Considerations for the Cleanup Script

The script provided previously will work on your `ubuntu-minimal` instance, but you should be aware of a few things:

  * **`sudo` is Essential:** Since this is a server-oriented OS, you'll need `sudo` for most system-level commands, like clearing the Docker cache or package manager caches, and for editing system files. The script already includes `sudo`, so that's covered.
  * **Docker May Not Be Pre-installed:** The minimal image likely does not come with Docker pre-installed. If your GitHub runner builds use Docker, you'll need to install it first. The `docker system prune` command will fail gracefully if Docker isn't installed, but you should confirm if it's necessary for your workflows and set it up if it is.
  * **Apt-get is Correct:** The `apt-get clean` command is the right tool for clearing the package cache on this Ubuntu version.
  * **`RUNNER_DIR` Path:** Double-check the path to your runner's work directory. A common location for a self-hosted runner is `/home/ubuntu/actions-runner/_work` or `/home/github-runner/actions-runner/_work`, depending on the user you set up. Make sure to adjust the `RUNNER_DIR` variable in the script accordingly.

### Creating and Editing the File on the Minimal OS

The main challenge with a minimal OS is the **lack of a graphical text editor**. You'll need to use a command-line editor.

#### 1\. Choose a Text Editor

A minimal Ubuntu image may not even have a simple editor like `nano` pre-installed. The most likely editors you'll find are `vi` or `vim.tiny`.

  * **`vi`**: A powerful but complex editor. It has a steep learning curve but is an essential skill for system administration. You have to switch between different modes to type and save.
  * **`nano`**: A much more user-friendly command-line editor. It shows the commands you can use at the bottom of the screen.

If you don't have `nano`, you can install it easily with the following command:

```bash
sudo apt update
sudo apt install -y nano
```

Since your instance is a minimal one, it is highly recommended to install `nano` to make editing the script easier.

#### 2\. Create and Edit the Script

Here are the steps to create and edit the script using `nano`:

1.  **Open the file in nano:**

    ```bash
    sudo nano /usr/local/bin/runner_cleanup.sh
    ```

    Using `sudo` here is a good practice to ensure you have permissions to write to that directory.

2.  **Paste the script content:** Copy the script from the previous response and paste it into the terminal. Most terminals support `Ctrl+Shift+V` to paste.

3.  **Adjust the `RUNNER_DIR` path:** Use the arrow keys to navigate to the line `RUNNER_DIR="/home/github-runner/actions-runner/_work"` and change the path if necessary.

4.  **Save the file:** Press `Ctrl+O` to write the file, then press `Enter` to confirm the filename.

5.  **Exit nano:** Press `Ctrl+X` to exit the editor.

6.  **Make the script executable:**

    ```bash
    sudo chmod +x /usr/local/bin/runner_cleanup.sh
    ```

#### 3\. Set Up the Cron Job

The process for setting up the cron job is exactly the same as described before. The `crontab` utility is a standard part of Ubuntu, including the minimal versions.

1.  Open the crontab for editing: `sudo crontab -e`
2.  Add the line: `0 3 * * * /usr/local/bin/runner_cleanup.sh >> /var/log/runner_cleanup.log 2>&1`
3.  Save and exit the editor.



-------------------------------------------------------------------------------------------------------



You can add the `runner_cleanup.sh` cron job directly to your Compute Engine instance's startup script. This automates the entire setup process, so the runner and the cleanup script are configured automatically every time the machine starts.

Here's how to structure the startup script to accomplish this:

### 1\. Create a Startup Script File

First, create a file named `startup_script.sh` on your local machine. This script will perform all the necessary setup tasks on your Compute Engine instance.

```bash
#!/bin/bash

# --- 1. Install prerequisites ---
echo "Updating package list and installing nano..."
sudo apt-get update
sudo apt-get install -y nano docker.io

# --- 2. Create the cleanup script ---
# The 'runner_cleanup.sh' script is written directly into a file.
echo "Creating the runner_cleanup.sh script..."

# This uses a 'cat' command to write the script to a file.
sudo cat << 'EOF' > /usr/local/bin/runner_cleanup.sh
#!/bin/bash

# Adjust this path to match your runner's installation directory.
RUNNER_DIR="/home/github-runner/actions-runner/_work"

echo "Starting daily runner cleanup at $(date)"

# Clean up Docker system
echo "Cleaning up Docker system..."
sudo docker system prune --all --force --volumes

# Clear package manager caches
if command -v apt-get &> /dev/null
then
    echo "Cleaning up APT cache..."
    sudo apt-get clean
fi

# Remove temporary files
echo "Cleaning up temporary files..."
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Clean up runner work directories
echo "Cleaning up runner work directories..."
if [ -d "$RUNNER_DIR" ]; then
  find "$RUNNER_DIR" -mindepth 1 -maxdepth 1 -exec sudo rm -rf {} +
fi

echo "Daily cleanup finished."
EOF

# Make the script executable
sudo chmod +x /usr/local/bin/runner_cleanup.sh

# --- 3. Add the cron job ---
# This adds a daily cron job for the cleanup script.
echo "Adding a daily cron job for the cleanup script..."

# Use 'crontab -l' to get the existing crontab, then add the new line.
# This prevents overwriting any existing cron jobs.
# The `(crontab -l 2>/dev/null; echo "...")` command is the standard way to do this.
(sudo crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/runner_cleanup.sh >> /var/log/runner_cleanup.log 2>&1") | sudo crontab -

echo "Startup script finished."
```

**Important:** Be sure to adjust the `RUNNER_DIR` variable within the script to match the exact location of your GitHub runner's installation directory.

-----

### 2\. Add the Startup Script to Your VM

You can add this startup script to your GCE instance in two ways:

#### A. When Creating a New VM

When you are creating a new Compute Engine instance in the Google Cloud Console, navigate to the **Automation** section. You can either paste the entire script into the **Startup script** box or upload the `startup_script.sh` file you created.

#### B. To an Existing VM

For an existing VM, you can add the script by editing the instance.

1.  In the Google Cloud Console, go to **Compute Engine \> VM instances**.
2.  Click on the instance you want to edit.
3.  Click the **EDIT** button at the top of the page.
4.  Scroll down to the **Automation** section.
5.  Paste the contents of your `startup_script.sh` file into the **Startup script** box.
6.  Click **SAVE**.

The next time you start the VM, the startup script will automatically execute, setting up the cleanup script and the cron job.
