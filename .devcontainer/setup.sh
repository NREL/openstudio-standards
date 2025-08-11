#!/bin/bash
set -e  # Exit on any error

echo "🚀 Starting devcontainer setup..."

# Check if we're on NRCAN network and install certificates if needed
if [ "$(curl -k -o /dev/null -s -w "%{http_code}" "https://intranet.nrcan.gc.ca/")" -ge 200 ] && [ "$(curl -o /dev/null -s -w "%{http_code}" "https://intranet.nrcan.gc.ca/")" -lt 400 ]; then
    echo "🔐 NRCAN network detected - installing certificates..."
    git clone https://github.com/canmet-energy/linux_nrcan_certs.git
    cd linux_nrcan_certs
    ./install_nrcan_certs.sh
    cd ..
    rm -fr linux_nrcan_certs
    echo 'export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt' >> /home/vscode/.bashrc
    export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
    echo "✅ NRCAN certificates installed"
else
    echo "🌐 Standard network detected - using default certificates"
fi

# Set up Python virtual environment
echo "🐍 Setting up Python virtual environment..."
/venv/bin/python -m venv ./.venv
echo "✅ Python virtual environment created"

# Set up Ruby bundle
echo "💎 Setting up Ruby bundle..."
cp Gemfile.lock.$OPENSTUDIO_VERSION Gemfile.lock
bundle config set path "./vendor/bundle"
bundle install
echo "✅ Ruby bundle installed"

# Install Node.js and related tools
echo "📦 Installing Node.js and tools..."
curl -fsSLk https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs python3-pip
pip install uv
sudo apt-get update
echo "✅ Node.js and tools installed"

# Install Claude and set up Serena MCP
echo "🤖 Installing Claude and Serena MCP..."
echo "📍 Current directory: $(pwd)"
sudo NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt npm install -g @anthropic-ai/claude-code
claude mcp add serena -- uv tool run --python 3.12 --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant --project "$(pwd)"
echo "✅ Claude and Serena MCP configured"

echo "🎉 Devcontainer setup complete!"
echo "📝 You can now use:"
echo "   - Claude with Serena MCP for advanced code analysis"
echo "   - GitHub Copilot for code completion"
echo "   - Python virtual environment at ./.venv"
echo "   - Ruby gems in ./vendor/bundle"
