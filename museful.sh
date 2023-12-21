TOP=$(pwd)
PATCHES=$TOP/device/phh/treble/patches
RESET=true
FAILED_PATCHES_FILE="$TOP/failed_patches.txt"
LOG_FILE="$TOP/patch_log.txt"  # Added a log file to store information about successful and failed patches

function patch() {
    local folder=$1
    local source_path=$2

    cd "$TOP/$source_path"

    if $RESET; then 
	git am --abort
        git reset --hard FETCH_HEAD
    fi

    git config --local user.name "jenkins"
    git config --local user.email "generic@email.com"
    
    git am "$folder"/* 2>> "$FAILED_PATCHES_FILE"
    if [ $? -ne 0 ]; then 
        echo "!!! WARNING: Patching failed for $source_path." >> "$FAILED_PATCHES_FILE"
        echo "Failed: $source_path" >> "$LOG_FILE"
	git am --abort
        git reset --hard FETCH_HEAD  # Revert to the state before applying the failed patches
    else
        echo "Successful: $source_path" >> "$LOG_FILE"
    fi
    
    git config --local --unset user.name
    git config --local --unset user.email
}

function apply() {
    for FOLDER in "$PATCHES/$1/"*; do
        PATCHDIR=$(basename "$FOLDER") # Remove additional path from DIR name

        SOURCEPATH=${PATCHDIR/platform_/} # Remove platform_ from dir name
        SOURCEPATH=${SOURCEPATH//_//} # replace _ with / to make a path to directory to patch

        if [ "$SOURCEPATH" == "build" ]; then 
            SOURCEPATH="build/make"
        fi # Replace build with build/make

        patch "$FOLDER" "$SOURCEPATH"
    done

    cd "$TOP"
    RESET=false
}

rm -rf vendor/hardware_overlay
git clone https://github.com/trebledroid/vendor_hardware_overlay vendor/hardware_overlay -b pie --depth 1

# ... (same for other repositories)

echo "Patching with TrebleDroid"
apply "TrebleDroid"
echo "Patching with UniversalX"
apply "UniversalX"

if [ -s "$FAILED_PATCHES_FILE" ]; then
    echo "Some patches failed. Check $FAILED_PATCHES_FILE for details."
fi

# Display the patch log
cat "$LOG_FILE"
