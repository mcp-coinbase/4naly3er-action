#!/usr/bin/env bash
# Exit immediately if a command exits with a non-zero status and ensure that all parts of a pipeline fail if any command fails
set -e -o pipefail

# Function to generate a random string of 20 characters
random_string() {
    # Generate a random string by combining multiple $RANDOM values, hashing them with md5sum, and taking the first 20 characters
    echo "$RANDOM $RANDOM $RANDOM $RANDOM $RANDOM" | md5sum | head -c 20
}

# Function to compare two version strings and check if the first version is less than or equal to the second version
version_lte() {
    # Print the two version strings, sort them using version sort (-V), and check if they are in the correct order (-C)
    printf '%s\n%s\n' "$1" "$2" | sort -C -V
}

install_solc() {
    if [[! -f "$(which solc-select)" ]]; then
        pip3 install solc-select      # Install solc-select if not installed
    fi
    # Check if SOLCVER is not set
    if [[ -z "$SOLCVER" ]]; then
        echo "[-] SOLCVER was not set; guessing."

        # Check if TARGET is a file
        if [[ -f "$TARGET" ]]; then
            # Extract the Solidity version from the pragma statement in the file
            SOLCVER="$(grep --no-filename '^pragma solidity' "$TARGET" | cut -d' ' -f3)"
        
        # Check if TARGET is a directory
        elif [[ -d "$TARGET" ]]; then
            # Change to the TARGET directory
            pushd "$TARGET" >/dev/null
            # Recursively search for Solidity files and extract the most common version from pragma statements
            SOLCVER="$(grep --no-filename '^pragma solidity' -r --include \*.sol --exclude-dir node_modules --exclude-dir dist | \
                       cut -d' ' -f3 | sort | uniq -c | sort -n | tail -1 | tr -s ' ' | cut -d' ' -f3)"
            # Return to the previous directory
            popd >/dev/null
        
        # If TARGET is neither a file nor a directory, assume it is a path glob
        else
            echo "[-] Target is neither a file nor a directory, assuming it is a path glob"
            # Use globbing to search for Solidity files and extract the most common version from pragma statements
            SOLCVER="$( shopt -s globstar; for file in $TARGET; do
                            grep --no-filename '^pragma solidity' -r "$file" ; \
                        done | cut -d' ' -f3 | sort | uniq -c | sort -n | tail -1 | tr -s ' ' | cut -d' ' -f3)"
        fi

        # Remove any non-numeric characters from the extracted version
        SOLCVER="$(echo "$SOLCVER" | sed 's/[^0-9\.]//g')"

        # If SOLCVER is still not set, fallback to the latest version
        if [[ -z "$SOLCVER" ]]; then
            SOLCVER="$(solc-select install | tail -1)"
        fi

        echo "[-] Guessed $SOLCVER."
    fi

    # Install the specified Solidity version
    solc-select install "$SOLCVER"
    # Use the specified Solidity version
    solc-select use "$SOLCVER"
}

install_node() {
    # Check if NODEVER is not set
    if [[ -z "$NODEVER" ]]; then
        NODEVER="node" # Default to the latest version of Node.js
        echo "[-] NODEVER was not set, using the latest version."
    fi

    # Download the NVM (Node Version Manager) install script
    wget -q -O nvm-install.sh https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh

    # Verify the checksum of the downloaded NVM install script
    if [ ! "fabc489b39a5e9c999c7cab4d281cdbbcbad10ec2f8b9a7f7144ad701b6bfdc7  nvm-install.sh" = "$(sha256sum nvm-install.sh)" ]; then
        echo "NVM installer does not match expected checksum! exiting"
        exit 1
    fi

    # Run the NVM install script
    bash nvm-install.sh

    # Remove the NVM install script after installation
    rm nvm-install.sh

    # Avoid picking up `.nvmrc` from the repository
    pushd / >/dev/null

    # Source the NVM script to make `nvm` command available in the current shell
    . ~/.nvm/nvm.sh

    # Install the specified version of Node.js using NVM
    nvm install "$NODEVER"

    # Return to the previous directory
    popd >/dev/null
}

install_foundry() {
    # Check if TARGET is a directory and contains a foundry.toml file
    if [[ -d "$TARGET" ]] && [[ -f "$TARGET/foundry.toml" ]]; then
        echo "[-] Foundry target detected, installing foundry nightly"

        # Download the Foundry installer script
        wget -q -O foundryup https://raw.githubusercontent.com/foundry-rs/foundry/7b452656f722fc560f0414db3ce24a1f2972a8b7/foundryup/foundryup

        # Verify the checksum of the downloaded Foundry installer script
        if [ ! "e7628766329e2873484d5d633c750b5019eec77ae506c11a0ef13b440cc3e7c2  foundryup" = "$(sha256sum foundryup)" ]; then
            echo "Foundry installer does not match expected checksum! exiting"
            exit 1
        fi

        # Set the Foundry installation directory
        export FOUNDRY_DIR="/opt/foundry"
        # Add the Foundry binary directory to the PATH
        export PATH="$FOUNDRY_DIR/bin:$PATH"
        # Create the necessary directories for Foundry
        mkdir -p "$FOUNDRY_DIR/bin" "$FOUNDRY_DIR/share/man/man1"
        # Run the Foundry installer script
        bash foundryup
        # Remove the Foundry installer script after installation
        rm foundryup
    fi
}

install_4naly3er() {
    # Download the forked repo and CD in
    git clone https://github.com/AnalyticETH/4naly3er
    cd 4naly3er
    # Install deps using Yarn
    yarn
    # Save 4naly3er path in TOOLPWD
    TOOLPWD=$(pwd)
    # Return to the previous directory
    cd .. 
}

install_deps() {
    # Check if TARGET is a directory
    if [[ -d "$TARGET" ]]; then
        # Change to the TARGET directory
        pushd "$TARGET" >/dev/null

        # Ensure that all dependency management systems are configured to use Artifactory here

        # JS dependencies
        if [[ -f package-lock.json ]]; then
            echo "[-] Installing dependencies from package-lock.json"
            npm ci # Install dependencies using npm ci (clean install)
        elif [[ -f yarn.lock ]]; then
            echo "[-] Installing dependencies from yarn.lock"
            npm install -g yarn # Install Yarn globally
            yarn install --frozen-lockfile # Install dependencies using Yarn with frozen lockfile
        elif [[ -f pnpm-lock.yaml ]]; then
            echo "[-] Installing dependencies from pnpm-lock.yaml"
            npm install -g pnpm # Install pnpm globally
            mkdir .pnpm-store # Create a directory for pnpm store
            pnpm config set store-dir .pnpm-store # Set the pnpm store directory
            pnpm install --frozen-lockfile # Install dependencies using pnpm with frozen lockfile
        elif [[ -f package.json ]]; then
            echo "[-] Did not detect a package-lock.json, yarn.lock, or pnpm-lock.yaml in $TARGET, consider locking your dependencies!"
            echo "[-] Proceeding with 'npm i' to install dependencies"
            npm i # Install dependencies using npm install
        else
            echo "[-] Did not find a package.json, proceeding without installing JS dependencies."
        fi

        # Python dependencies
        if [[ -f requirements.txt ]]; then
            echo "[-] Installing dependencies from requirements.txt in a venv"
            python3 -m venv /opt/dependencies # Create a virtual environment
            OLDPATH="$PATH" # Save the old PATH
            export PATH="/opt/dependencies/bin:$PATH" # Update PATH to include the virtual environment
            pip3 install wheel # Install wheel package
            pip3 install -r requirements.txt # Install dependencies from requirements.txt
            # Add to the end of PATH, to give preference to the action's tools
            export PATH="$OLDPATH:/opt/dependencies/bin" # Restore the old PATH and append the virtual environment
        else
            echo "[-] Did not find a requirements.txt, proceeding without installing Python dependencies."
        fi

        # Foundry dependencies
        if [[ -f foundry.toml ]]; then
            echo "[-] Installing dependencies from foundry.toml"
            forge install # Install dependencies using Foundry
        else
            echo "[-] Did not find a foundry.toml, proceeding without installing Foundry dependencies."
        fi

        # Return to the previous directory
        popd >/dev/null
    fi
}

utput_stdout() {
    # Generate a random delimiter using the random_string function
    DELIMITER="$(random_string)"
    
    # Append the output to the GITHUB_OUTPUT file
    {
        # Print the start of the stdout section with the delimiter
        echo "stdout<<$DELIMITER"
        
        # Concatenate the contents of the STDOUTFILE
        cat "$STDOUTFILE"
        
        # Print the delimiter to mark the end of the stdout section
        echo -e "\n$DELIMITER"
    } >> "$GITHUB_OUTPUT"
}


##################################################################
##################################################################


################## Install the tool and deps ##################
install_4naly3er
install_solc
install_node # already installed
install_foundry # already installed
install_deps


################## Prepare inputs to the tool ##################
################## Save PWD of project (arg 1) ##################
CONTRACTSPWD=$(pwd)    


################## Determine Foundry/Hardhat and scoped folder (arg 2, part 1) ##################
if [[ -f foundry.toml ]]; then
    PROJECTSCOPE="src" # Foundry 'src' folder will be the scoped folder
elif [[ -f hardhat.config.ts ]]; then
    PROJECTSCOPE="contracts" # Hardhat 'contracts' folder will be the scoped folder
else
    PROJECTSCOPE="." # Undetermined; the entire repo will be the scoped folder
fi


################## Generate scoping file to /tmp/scope.txt (arg 2, part 2) ##################
if [! -f "$CONTRACTSPWD/scope.txt" ]; then      # We are already in $CONTRACTSPWD
    find .| grep $PROJECTSCOPE | grep sol | grep -v typechain | grep -v node_modules | grep -v artifacts | grep -v "\.t\.sol">/tmp/scope.txt
else
    cp $CONTRACTSPWD/scope.txt /tmp/scope.txt
fi


################## Saving github url (arg 3) ##################
URLPREFIX="https://github.com/"
PROJECTURL= "$URLPREFIX$GITHUB_REPOSITORY/"


###### TESTING #####
echo "PROJECTSCOPE is $PROJECTSCOPE"
echo "CONTRACTSPWD is $CONTRACTSPWD"
echo "PROJECTURL is $PROJECTURL"
echo "cat /tmp/scope.txt"
cat /tmp/scope.txt
###### TESTING #####


################## Run the tool ##################
trap "output_stdout" EXIT # Set a trap to call the output_stdout function when the script exits
cd $TOOLPWD             # Move to 4naly3er folder (required to run it)
yarn analyze $CONTRACTSPWD /tmp/scope.txt $PROJECTURL # Finally, run the tool
exit 0 # Exit success