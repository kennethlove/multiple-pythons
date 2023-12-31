#!/bin/bash -i
set -ex

VERSIONS=${VERSIONS:-""}
REQUIREMENTSFILE=${REQUIREMENTSFILE:-""}

# Clean up
rm -rf /var/lib/apt/lists/*

if [ -z "$VERSIONS" ]; then
	echo -e "'versions' variable is empty, skipping"
	exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
	echo -e 'Script must be run as
    root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
	exit 1
fi

check_alpine_packages() {
    apk add -v --no-cache "$@"
}

check_packages() {
	if ! dpkg -s "$@" >/dev/null 2>&1; then
		if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
			echo "Running apt-get update..."
			apt-get update -y
		fi
		apt-get -y install --no-install-recommends "$@"
	fi
}

ensure_prereqs() {
    check_packages libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev curl git ca-certificates

    if ! type yq >/dev/null 2>&1; then
        ARCHITECTURE="$(uname -m)"
        case ${ARCHITECTURE} in
        x86_64) ARCHITECTURE="amd64" ;;
        aarch64 | armv8*) ARCHITECTURE="arm64" ;;
        aarch32 | armv7* | armvhf*) ARCHITECTURE="arm" ;;
        i?86) ARCHITECTURE="386" ;;
        *)
        	echo "(!) Architecture ${ARCHITECTURE} unsupported"
            exit 1
            ;;
        esac
        echo "Installing yq..."
        wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$ARCHITECTURE -O /usr/bin/yq
        chmod +x /usr/bin/yq
    else
        echo "'yq' is already installed"
    fi
}

ensure_asdf_is_installed() {
    ASDF_BASEPATH="$_REMOTE_USER_HOME/.asdf"

	set -e
	su - "$_REMOTE_USER" <<EOF
		if type asdf >/dev/null 2>&1; then
			exit
		elif [ -f "$ASDF_BASEPATH/asdf.sh" ]; then
            exit
        fi

        git clone --depth=1 \
        -c core.eol=lf \
        -c core.autocrlf=false \
        -c fsck.zeroPaddedFilemode=ignore \
        -c fetch.fsck.zeroPaddedFilemode=ignore \
        -c receive.fsck.zeroPaddedFilemode=ignore \
        "https://github.com/asdf-vm/asdf.git" --branch v0.12.0 $ASDF_BASEPATH 2>&1
EOF

    if cat /etc/os-release | grep "ID_LIKE=.*alpine.*\|ID=.*alpine.*" ; then
        echo "Updating /etc/profile"
        echo -e "export ASDF_DIR=\"$ASDF_BASEPATH\"" >>/etc/profile
        echo -e ". $ASDF_BASEPATH/asdf.sh" >>/etc/profile
    fi
    if [[ "$(cat /etc/bash.bashrc)" != *"$ASDF_BASEPATH"* ]]; then
        echo "Updating /etc/bash.bashrc"
        echo -e ". $ASDF_BASEPATH/asdf.sh" >>/etc/bash.bashrc
        echo -e ". $ASDF_BASEPATH/completions/asdf.bash" >>/etc/bash.bashrc
    fi
    if [ -f "/etc/zsh/zshrc" ] && [[ "$(cat /etc/zsh/zshrc)" != *"$ASDF_BASEPATH"* ]]; then
        echo "Updating /etc/zsh/zshrc"
        echo -e ". $ASDF_BASEPATH/asdf.sh" >>/etc/zsh/zshrc
        echo -e "fpath=(\${ASDF_DIR}/completions \$fpath)" >>/etc/zsh/zshrc
        echo -e "autoload -Uz compinit && compinit" >>/etc/zsh/zshrc
    fi
    if [ -f "/etc/fish/config.fish" ] && [[ "$(cat /etc/fish/config.fish)" != *"$ASDF_BASEPATH"* ]]; then
        echo "Updating /etc/fish/config.fish"
        echo -e "source $ASDF_BASEPATH/asdf.fish" >>/etc/fish/config.fish
        ln -s $ASDF_BASEPATH/completions/asdf.fish /etc/fish/completions
    fi
}

ensure_asdf_plugin_is_installed() {
    PLUGIN=$1
    REPO=$2

    su - "$_REMOTE_USER" <<EOF
        . $_REMOTE_USER_HOME/.asdf/asdf.sh

        if asdf list "$PLUGIN" >/dev/null 2>&1; then
            echo "'$PLUGIN' asdf plugin already exists - skipping adding it"
        else
            asdf plugin add $PLUGIN
        fi
EOF
}

install_python_via_asdf() {
    VERSION=$1

	set -e

    su - "$_REMOTE_USER" <<EOF
        . $_REMOTE_USER_HOME/.asdf/asdf.sh

        if [ -n "$REQUIREMENTSFILE" ]; then
            echo "Requirements file '$REQUIREMENTSFILE' exists with contents: $(cat $REQUIREMENTSFILE | tr '\n' ',')"
            echo "Setting variable ASDF_PYTHON_DEFAULT_PACKAGES_FILE to $REQUIREMENTSFILE"
            export ASDF_PYTHON_DEFAULT_PACKAGES_FILE="$REQUIREMENTSFILE"
        fi

        asdf install python "$VERSION"
        asdf global python "$VERSION"

        pip install --upgrade pip
EOF
}

ensure_supporting_tools_are_installed() {
    su - "$_REMOTE_USER" <<EOF
        . $_REMOTE_USER_HOME/.asdf/asdf.sh

        ensure_pipx_app_is_installed() {
            PIPX_APP=\$1

            if ! type \$PIPX_APP >/dev/null 2>&1; then
                echo "Installing '\$PIPX_APP' via pipx..."
                pipx install "\$PIPX_APP"
            else
                echo "'\$PIPX_APP' is already installed"
            fi
        }

        ensure_pipx_injection() {
            ENV=\$1
            INJECTION=\$2

            if ! pipx list --include-injected --json | yq '.venvs.strenv(ENV).metadata.injected_packages | has("strenv(INJECTION)")' -o json; then
                echo "Injecting '\$INJECTION' into '\$ENV' via pipx..."
                pipx inject \$ENV \$INJECTION
            else
                echo "'\$ENV' already has '\$INJECTION' injected"
            fi

        }

        if ! type pipx >/dev/null 2>&1; then
            if asdf list pipx >/dev/null 2>&1; then
                echo "'pipx' asdf plugin already exists - skipping adding it"
            else
                asdf plugin add pipx
            fi
            echo "Installing 'pipx' via asdf..."
            asdf install pipx latest
            asdf global pipx latest
            pipx ensurepath
        else
            echo "pipx is already installed"
        fi
EOF
}

# Ensure the prereqs for asdf and building python are installed
ensure_prereqs

# Install asdf and its requirements (if needed)
ensure_asdf_is_installed

# Add python asdf plugin, if needed
ensure_asdf_plugin_is_installed "python"

# Install Python versions
set -- $VERSIONS
while [ -n "$1" ]; do
    PLUGINNAME="python"
    VERSION="latest:$1"

	install_python_via_asdf "$VERSION"
	shift
done

# Install Hypermodern Python supporting tools
ensure_supporting_tools_are_installed
