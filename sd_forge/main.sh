#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Stable Diffusion WebUI Forge ###"
log "Setting up Stable Diffusion WebUI Forge"
if [[ "$REINSTALL_SD_FORGE" || ! -f "/tmp/sd_forge.prepared" ]]; then

    TARGET_REPO_URL="https://github.com/lllyasviel/stable-diffusion-webui-forge" \
    TARGET_REPO_DIR=$REPO_DIR \
    UPDATE_REPO=$SD_FORGE_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$SD_FORGE_UPDATE_REPO_COMMIT \
    prepare_repo 

    symlinks=(
        "$REPO_DIR/outputs:$IMAGE_OUTPUTS_DIR/stable-diffusion-forge"
        "$MODEL_DIR:$WORKING_DIR/models"
        "$MODEL_DIR/sd:$LINK_MODEL_TO"
        "$MODEL_DIR/lora:$LINK_LORA_TO"
        "$MODEL_DIR/vae:$LINK_VAE_TO"
        "$MODEL_DIR/hypernetwork:$LINK_HYPERNETWORK_TO"
        "$MODEL_DIR/controlnet:$LINK_CONTROLNET_TO"
        "$MODEL_DIR/embedding:$LINK_EMBEDDING_TO"
    )
    prepare_link  "${symlinks[@]}"

    #Prepare the controlnet model dir
    #mkdir -p $MODEL_DIR/controlnet/
    # cp $LINK_CONTROLNET_TO/*.yaml $MODEL_DIR/controlnet/
    rm -rf $VENV_DIR/sd_forge-env
    
    
    python3.10 -m venv $VENV_DIR/sd_forge-env
    
    source $VENV_DIR/sd_forge-env/bin/activate

    pip install --upgrade pip
    pip install --upgrade wheel setuptools
    
    # fix install issue with pycairo, which is needed by sd-webui-controlnet
    apt-get install -y libcairo2-dev libjpeg-dev libgif-dev
    pip uninstall -y torch torchvision torchaudio protobuf lxml tensorflow

    export PYTHONPATH="$PYTHONPATH:$REPO_DIR"
    # must run inside webui dir since env['PYTHONPATH'] = os.path.abspath(".") existing in launch.py
    cd $REPO_DIR
    python $current_dir/preinstall.py
    cd $current_dir

    pip install xformers
    pip uninstall -y torchvision
    pip install  torchvision
    touch /tmp/sd_forge.prepared
else
    
    source $VENV_DIR/sd_forge-env/bin/activate
    
fi
log "Finished Preparing Environment for Stable Diffusion WebUI Forge"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Stable Diffusion WebUI ###"
  log "Downloading Model for Stable Diffusion WebUI"
  bash $current_dir/../utils/sd_model_download/main.sh
  log "Finished Downloading Models for Stable Diffusion WebUI"
else
  log "Skipping Model Download for Stable Diffusion WebUI"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Stable Diffusion WebUI Forge###"
  log "Starting Stable Diffusion WebUI Forge"
  cd $REPO_DIR
  auth=""
  if [[ -n "${SD_FORGE_GRADIO_AUTH}" ]]; then
    auth="--gradio-auth ${SD_FORGE_GRADIO_AUTH}"
  fi
  PYTHONUNBUFFERED=1 service_loop "python webui.py --port $SD_FORGE_PORT --subpath sd-webui $auth --controlnet-dir $MODEL_DIR/controlnet/ --enable-insecure-extension-access ${EXTRA_SD_FORGE_ARGS}" > $LOG_DIR/sd_forge.log 2>&1 &
  echo $! > /tmp/sd_forge.pid
fi


send_to_discord "Stable Diffusion WebUI Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/sd-forge/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"sd_forge"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,sd_forge"
  fi
  bash $current_dir/../cloudflare_reload.sh
fi

echo "### Done ###"