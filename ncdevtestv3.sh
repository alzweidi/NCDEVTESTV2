#!/bin/bash

set -e

### CONFIG
REPO_URL="https://github.com/zorp-corp/nockchain"
PROJECT_DIR="$HOME/nockchain"
PUBKEY="36GCyFUigP88aQ29Ri9cGncrEtbCxSbD7SrBU6fYR5e98GqaNSQMnN1HMw6Em1SyLUy766YZwkRe5ccHLNxac59S7yykE2pN7U5jFZpXgmN5hihZi7acicWHnXkNKYNp7aBy"  # <-- Your shared wallet public key
LEADER_PORT=3005
FOLLOWER_PORT=3006

echo ""
echo "[+] Nockchain DevNet Bootstrap Starting..."
echo "-------------------------------------------"

### 1. Install Rust Toolchain
if ! command -v cargo &> /dev/null; then
  echo "[1/6] Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
else
  echo "[1/6] Rust already installed."
fi

### 2. Install dependencies
echo "[2/6] Installing dependencies..."
sudo apt update && sudo apt install -y \
  git \
  make \
  build-essential \
  clang \
  llvm-dev \
  libclang-dev \
  tmux

### 3. Clone repo
echo "[3/6] Cloning Nockchain repo..."
if [ ! -d "$PROJECT_DIR" ]; then
  git clone "$REPO_URL" "$PROJECT_DIR"
else
  echo "    Repo already exists. Pulling latest..."
  cd "$PROJECT_DIR"
  git pull origin main
fi
cd "$PROJECT_DIR"

### 4. Install Choo
echo "[4/6] Installing Choo (Nock/Hoon compiler)..."
make install-choo

### 5. Build project
echo "[5/6] Building Nockchain project..."
make build-hoon-all
make build

### 6. Launch Leader & Follower in tmux with your wallet public key
echo "[6/6] Launching Nockchain Leader & Follower in tmux..."

# Kill any previous tmux sessions
tmux kill-session -t nock-leader 2>/dev/null || true
tmux kill-session -t nock-follower 2>/dev/null || true

# Clean old sockets/state
rm -f "$PROJECT_DIR/nockchain.sock"
rm -rf "$PROJECT_DIR/.data.nockchain"

# Launch Leader
tmux new-session -d -s nock-leader "cd $PROJECT_DIR && ./target/release/nockchain \
  --fakenet \
  --genesis-leader \
  --mine \
  --mining-pubkey $PUBKEY \
  --npc-socket nockchain.sock \
  --bind /ip4/0.0.0.0/udp/$LEADER_PORT/quic-v1 \
  --peer /ip4/127.0.0.1/udp/$FOLLOWER_PORT/quic-v1 \
  --new-peer-id \
  --no-default-peers | tee leader.log"

# Wait a few seconds to ensure leader starts first
sleep 5

# Launch Follower
tmux new-session -d -s nock-follower "cd $PROJECT_DIR && ./target/release/nockchain \
  --fakenet \
  --mine \
  --mining-pubkey $PUBKEY \
  --npc-socket nockchain.sock \
  --bind /ip4/0.0.0.0/udp/$FOLLOWER_PORT/quic-v1 \
  --peer /ip4/127.0.0.1/udp/$LEADER_PORT/quic-v1 \
  --new-peer-id \
  --no-default-peers | tee follower.log"
