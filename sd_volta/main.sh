#!/bin/bash
set -e

# Define a function to echo a message and exit
error_exit() {
    echo "$1" >&2
    exit 1
}

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR

current_dir=$(dirname "$(realpath "$0")")
echo "### Setting up Stable Diffusion Volta ###"
symlinks=(
    "$REPO_DIR:$WORKING_DIR/stable-diffusion-volta"
    "$OUTPUTS_DIR:$WORKING_DIR/storage"
    "$REPO_DIR/data/outputs:$IMAGE_OUTPUTS_DIR/stable-diffusion-volta"
    "$MODEL_DIR:$WORKING_DIR/models"
)
TARGET_REPO_URL="https://github.com/VoltaML/voltaML-fast-stable-diffusion.git" \
TARGET_REPO_DIR=$REPO_DIR \
TARGET_REPO_BRANCH=main \
UPDATE_REPO=$SD_VOLTA_UPDATE_REPO \
UPDATE_REPO_COMMIT=$SD_VOLTA_UPDATE_REPO_COMMIT \
bash $current_dir/../utils/prepare_repo.sh "${symlinks[@]}"
if ! [[ -e "/tmp/sd_volta.prepared" ]]; then
    
    python3.10 -m venv /tmp/sd_volta-env
    source /tmp/sd_volta-env/bin/activate

    pip install --upgrade pip
    pip install --upgrade wheel setuptools
    
    cd $REPO_DIR
    python main.py --install-only

    pip install xformers
    
    touch /tmp/sd_volta.prepared
else
    
    source /tmp/sd_volta-env/bin/activate
    
fi
echo "Finished Preparing Environment for Stable Diffusion Volta"


log "### Downloading Model for Stable Diffusion Volta ###"
bash $current_dir/../utils/model_download/main.sh
python $current_dir/../utils/model_download/link_model.py
log "Finished Downloading Models for Stable Diffusion Volta"


echo "### Starting Stable Diffusion Volta ###"
cd "$REPO_DIR"
nohup python main.py > /tmp/{{ name }}.log 2>&1 &
echo $! > /tmp/{{ name }}.pid
log "Stable Diffusion Volta Started"
echo "### Done ###"