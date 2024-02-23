#!/bin/bash
# Don't exit on error

function source_env_file() {
  if [[ -e ".env" ]]; then
    source ".env"
  fi
}

function check_required_env_vars() {
  local required_vars=($(echo "$REQUIRED_ENV" | tr ',' '\n'))
  local missing_vars=()
  for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
      missing_vars+=("$var")
    fi
  done
  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "The following required environment variables are missing: ${missing_vars[*]}"
    return 1
  fi
  return 0
}

export SCRIPT_ROOT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
cd $SCRIPT_ROOT_DIR
source_env_file

# Prepare Path (for local install)
mkdir -p $DATA_DIR
mkdir -p $WORKING_DIR
mkdir -p $ROOT_REPO_DIR
mkdir -p $VENV_DIR
mkdir -p $LOG_DIR

echo "Installing common dependencies"
apt-get update -qq
apt-get install -qq -y curl jq git-lfs ninja-build \
    aria2 zip python3-venv python3-dev python3.10 \
    python3.10-venv python3.10-dev python3.10-tk  > /dev/null

if env | grep -q "PAPERSPACE"; then
  # Add alias to check the status of the web app
  chmod +x $WORKING_DIR/status_check.py
  echo "alias status='watch -n 1 /$WORKING_DIR/status_check.py'" >> ~/.bashrc
  echo "alias webuistatus='watch -n 0.1 \"tac /tmp/log/sd_webui.log\"'" >> ~/.bashrc
  echo "alias comfystatus='watch -n 0.1 \"tac /tmp/log/sd_comfy.log\"'" >> ~/.bashrc
  echo "alias forgestatus='watch -n 0.1 \"tac /tmp/log/sd_forge.log\"'" >> ~/.bashrc
  echo "alias runstatus='watch -n 0.1 \"tac /tmp/run.log\"'" >> ~/.bashrc
  # Use Nginx to expose web app in Paperspace
  apt-get install -qq -y nginx > /dev/null
  cp /$WORKING_DIR/nginx/default /etc/nginx/sites-available/default
  cp /$WORKING_DIR/nginx/nginx.conf /etc/nginx/nginx.conf
  /usr/sbin/nginx
fi

# Read the RUN_SCRIPT environment variable
run_script="$RUN_SCRIPT,sd_forge"

# Separate the variable by commas
IFS=',' read -ra scripts <<< "$run_script"

# Prepare required path
mkdir -p $IMAGE_OUTPUTS_DIR
if [[ ! -d $WORKING_DIR/image_outputs ]]; then
  ln -s $IMAGE_OUTPUTS_DIR $WORKING_DIR/image_outputs
fi

# Loop through each script and execute the corresponding case
echo "Starting script(s)"
for script in "${scripts[@]}"
do
  cd $SCRIPT_ROOT_DIR
  if [[ ! -d $script ]]; then
    echo "Script folder $script not found, skipping..."
    continue
  fi
  cd $script
  source_env_file
  if ! check_required_env_vars; then
    echo "One or more required environment variables are missing."
    continue
  fi
  bash control.sh reload
done
