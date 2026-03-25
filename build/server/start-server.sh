#!/usr/bin/env bash
# Greedy Bastards — Dedicated Server
# Uso: ./start-server.sh [--port PORT] [--players MAX]

set -euo pipefail

SERVER_BIN="$(dirname "$0")/GreedyBastards-server.x86_64"
ARGS="--headless -- --server"
LOG_FILE="$(dirname "$0")/server.log"

if [[ ! -f "$SERVER_BIN" ]]; then
    echo "[ERRO] Binário não encontrado: $SERVER_BIN"
    echo "Gere o build com: godot --headless --export-release 'Linux Server'"
    exit 1
fi

echo "============================================"
echo "  Greedy Bastards — Servidor Dedicado"
echo "  Porta: 7777 (UDP)"
echo "  Tunnel: wing-strict.gl.at.ply.gg:54603"
echo "  Log: $LOG_FILE"
echo "============================================"
echo ""

# Reinicia automaticamente se o servidor cair
while true; do
    echo "[$(date '+%H:%M:%S')] Iniciando servidor..."
    "$SERVER_BIN" $ARGS 2>&1 | tee -a "$LOG_FILE"
    echo "[$(date '+%H:%M:%S')] Servidor encerrou. Reiniciando em 3s..."
    sleep 3
done
