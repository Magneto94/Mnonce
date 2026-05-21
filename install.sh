#!/bin/bash
# ============================================================
#  NONCE (ERC-8004) CPU Miner — Auto Installer
#  Untuk Vast.ai / Ubuntu VPS
#  Cara pakai:
#    bash install.sh
#  atau one-liner:
#    curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash
# ============================================================

set -e

# ── WARNA ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── BANNER ──────────────────────────────────────────────────
clear
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════╗"
echo "║      NONCE ERC-8004 CPU Miner Installer          ║"
echo "║      Base Mainnet · Vast.ai Edition              ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── CEK OS ──────────────────────────────────────────────────
if ! grep -qi "ubuntu\|debian" /etc/os-release 2>/dev/null; then
  echo -e "${YELLOW}[!] Script ini dioptimalkan untuk Ubuntu/Debian.${NC}"
fi

INSTALL_DIR="$HOME/nonce-miner"

# ── INPUT KONFIGURASI ────────────────────────────────────────
echo -e "${BOLD}━━━ KONFIGURASI MINER ━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Private Key
while true; do
  read -rsp "🔑 Masukkan PRIVATE KEY wallet (input tersembunyi): " PRIVATE_KEY
  echo ""
  if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}[!] Private key tidak boleh kosong!${NC}"
  elif [ ${#PRIVATE_KEY} -lt 60 ]; then
    echo -e "${RED}[!] Private key terlalu pendek, cek lagi.${NC}"
  else
    break
  fi
done

# Tambah 0x kalau belum ada
[[ "$PRIVATE_KEY" != 0x* ]] && PRIVATE_KEY="0x$PRIVATE_KEY"

echo ""

# CPU Threads
TOTAL_CPU=$(nproc)
DEFAULT_THREADS=$((TOTAL_CPU > 1 ? TOTAL_CPU - 1 : 1))
read -rp "🖥️  Jumlah CPU thread [default: ${DEFAULT_THREADS} dari ${TOTAL_CPU} core]: " CPU_THREADS
CPU_THREADS=${CPU_THREADS:-$DEFAULT_THREADS}

echo ""

# RPC URL
read -rp "🌐 RPC URL Base [Enter = pakai default]: " RPC_URL
RPC_URL=${RPC_URL:-"https://mainnet.base.org"}

echo ""

# Telegram
echo -e "${CYAN}📱 Setup Telegram Notifikasi (opsional, Enter untuk skip):${NC}"
echo -e "   Cara dapat BOT_TOKEN: chat ${BOLD}@BotFather${NC} → /newbot"
echo -e "   Cara dapat CHAT_ID  : chat ${BOLD}@userinfobot${NC} → /start"
echo ""
read -rp "   BOT_TOKEN  : " TG_BOT_TOKEN
read -rp "   CHAT_ID    : " TG_CHAT_ID

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ── KONFIRMASI ───────────────────────────────────────────────
echo -e "${BOLD}Ringkasan konfigurasi:${NC}"
echo -e "  CPU Threads : ${GREEN}${CPU_THREADS}${NC} (dari ${TOTAL_CPU} core)"
echo -e "  RPC URL     : ${GREEN}${RPC_URL}${NC}"
WALLET_PREVIEW="${PRIVATE_KEY:0:6}...${PRIVATE_KEY: -4}"
echo -e "  Private Key : ${GREEN}${WALLET_PREVIEW}${NC} (tersembunyi)"
if [ -n "$TG_BOT_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
  echo -e "  Telegram    : ${GREEN}✓ Aktif${NC}"
else
  echo -e "  Telegram    : ${YELLOW}✗ Dilewati${NC}"
fi
echo ""
read -rp "Lanjutkan instalasi? [Y/n]: " CONFIRM
CONFIRM=${CONFIRM:-Y}
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Instalasi dibatalkan."
  exit 0
fi

echo ""

# ── STEP 1: UPDATE SISTEM ────────────────────────────────────
echo -e "${CYAN}[1/6] Update sistem...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get upgrade -y -qq 2>/dev/null || true
echo -e "${GREEN}✓ Sistem diupdate${NC}"

# ── STEP 2: INSTALL DEPENDENSI ───────────────────────────────
echo -e "${CYAN}[2/6] Install dependensi dasar...${NC}"
apt-get install -y -qq curl wget unzip build-essential 2>/dev/null || true
echo -e "${GREEN}✓ Dependensi terinstall${NC}"

# ── STEP 3: INSTALL NODE.JS 20 ───────────────────────────────
echo -e "${CYAN}[3/6] Install Node.js 20 LTS...${NC}"
if command -v node &>/dev/null && node -e "process.exit(parseInt(process.version.slice(1)) >= 18 ? 0 : 1)" 2>/dev/null; then
  echo -e "${GREEN}✓ Node.js $(node --version) sudah ada${NC}"
else
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 2>/dev/null
  apt-get install -y nodejs 2>/dev/null
  echo -e "${GREEN}✓ Node.js $(node --version) terinstall${NC}"
fi

# ── STEP 4: INSTALL PM2 ──────────────────────────────────────
echo -e "${CYAN}[4/6] Install PM2...${NC}"
npm install -g pm2 --silent 2>/dev/null
echo -e "${GREEN}✓ PM2 $(pm2 --version) terinstall${NC}"

# ── STEP 5: BUAT FILE MINER ──────────────────────────────────
echo -e "${CYAN}[5/6] Membuat file miner...${NC}"
mkdir -p "$INSTALL_DIR/logs"

# ── package.json ─────────────────────────────────────────────
cat > "$INSTALL_DIR/package.json" << 'PKGJSON'
{
  "name": "nonce-erc8004-miner",
  "version": "2.0.0",
  "description": "CPU Miner untuk NONCE (ERC-8004) di Base Mainnet",
  "main": "miner.js",
  "scripts": {
    "start": "node -r dotenv/config miner.js"
  },
  "dependencies": {
    "dotenv": "^16.4.5",
    "ethers": "^6.13.2"
  },
  "engines": { "node": ">=18.0.0" }
}
PKGJSON

# ── ecosystem.config.js ──────────────────────────────────────
cat > "$INSTALL_DIR/ecosystem.config.js" << 'ECOSYSTEM'
module.exports = {
  apps: [{
    name            : "nonce-miner",
    script          : "miner.js",
    node_args       : "-r dotenv/config",
    instances       : 1,
    autorestart     : true,
    watch           : false,
    max_memory_restart: "512M",
    restart_delay   : 5000,
    max_restarts    : 999,
    min_uptime      : "10s",
    log_file        : "./logs/pm2-combined.log",
    out_file        : "./logs/pm2-out.log",
    error_file      : "./logs/pm2-error.log",
    log_date_format : "YYYY-MM-DD HH:mm:ss",
    merge_logs      : true,
  }],
};
ECOSYSTEM

# ── miner.js ─────────────────────────────────────────────────
cat > "$INSTALL_DIR/miner.js" << 'MINERJS'
#!/usr/bin/env node
// ============================================================
//  NONCE (ERC-8004) CPU Miner v2 — Vast.ai Edition
//  Chain   : Base Mainnet (chainId 8453)
//  Contract: 0xE7bADd12bdf070e925A55A98c981f3aBAB4f20cc
// ============================================================
const { Worker, isMainThread, parentPort, workerData } = require("worker_threads");
const { ethers } = require("ethers");
const crypto = require("crypto");
const os     = require("os");
const fs     = require("fs");
const path   = require("path");
const https  = require("https");

const CONFIG = {
  RPC_URL         : process.env.RPC_URL          || "https://mainnet.base.org",
  PRIVATE_KEY     : process.env.PRIVATE_KEY       || "",
  CONTRACT_ADDRESS: "0xE7bADd12bdf070e925A55A98c981f3aBAB4f20cc",
  CPU_THREADS     : parseInt(process.env.CPU_THREADS) || Math.max(1, os.cpus().length - 1),
  LOG_FILE        : process.env.LOG_FILE          || "./logs/miner.log",
  GAS_LIMIT       : 250000,
  GAS_PRICE_GWEI  : process.env.GAS_PRICE_GWEI   || "0.002",
  RETRY_DELAY_MS  : 5000,
  TG_BOT_TOKEN    : process.env.TG_BOT_TOKEN      || "",
  TG_CHAT_ID      : process.env.TG_CHAT_ID        || "",
};

const CONTRACT_ABI = [
  "function getChallenge(address miner) external view returns (bytes32)",
  "function getMiningDifficulty() external view returns (uint256)",
  "function mint(uint256 nonce) external",
  "function miningOpen() external view returns (bool)",
  "function getMiningReward() external view returns (uint256)",
  "function mintCount() external view returns (uint256)",
  "function balanceOf(address) external view returns (uint256)",
];

// ── Logger ──────────────────────────────────────────────────
const logDir = path.dirname(CONFIG.LOG_FILE);
if (!fs.existsSync(logDir)) fs.mkdirSync(logDir, { recursive: true });
function log(level, msg) {
  const line = `[${new Date().toISOString()}] [${level}] ${msg}`;
  console.log(line);
  fs.appendFileSync(CONFIG.LOG_FILE, line + "\n");
}
const logger = {
  info   : (m) => log("INFO ", m),
  warn   : (m) => log("WARN ", m),
  error  : (m) => log("ERROR", m),
  success: (m) => log("OK   ", m),
};

// ── Telegram ────────────────────────────────────────────────
function sendTelegram(message) {
  if (!CONFIG.TG_BOT_TOKEN || !CONFIG.TG_CHAT_ID) return;
  const body = JSON.stringify({ chat_id: CONFIG.TG_CHAT_ID, text: message, parse_mode: "HTML" });
  const req = https.request({
    hostname: "api.telegram.org",
    path    : `/bot${CONFIG.TG_BOT_TOKEN}/sendMessage`,
    method  : "POST",
    headers : { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(body) },
  }, (res) => { if (res.statusCode !== 200) logger.warn(`Telegram HTTP ${res.statusCode}`); });
  req.on("error", (e) => logger.warn(`Telegram error: ${e.message}`));
  req.write(body); req.end();
}

// ── Worker Thread ────────────────────────────────────────────
if (!isMainThread) {
  const { challenge, difficulty, workerId, rangeStart, rangeSize } = workerData;
  const challengeBuffer = Buffer.from(challenge.replace("0x", ""), "hex");
  const target = BigInt("0x" + "0".repeat(difficulty) + "f".repeat(64 - difficulty));
  let nonce = BigInt(rangeStart);
  const rangeEnd = BigInt(rangeStart) + BigInt(rangeSize);
  let hashes = 0;
  const startTime = Date.now();
  while (nonce < rangeEnd) {
    const nonceBuf = Buffer.alloc(32);
    let tmp = nonce;
    for (let i = 31; i >= 0; i--) { nonceBuf[i] = Number(tmp & 0xffn); tmp >>= 8n; }
    const hash = crypto.createHash("sha256").update(Buffer.concat([challengeBuffer, nonceBuf])).digest("hex");
    hashes++;
    if (BigInt("0x" + hash) <= target) {
      parentPort.postMessage({ type: "SOLUTION", nonce: nonce.toString(), hash, hashes, elapsed: Date.now() - startTime });
      return;
    }
    nonce++;
    if (hashes % 100_000 === 0) {
      parentPort.postMessage({ type: "PROGRESS", workerId, hashes, hashrate: Math.floor(hashes / ((Date.now() - startTime) / 1000)) });
    }
  }
  parentPort.postMessage({ type: "EXHAUSTED", hashes });
  return;
}

// ── Main ─────────────────────────────────────────────────────
async function main() {
  logger.info("================================================");
  logger.info("   NONCE ERC-8004 CPU Miner v2 - Vast.ai       ");
  logger.info("================================================");

  if (!CONFIG.PRIVATE_KEY) { logger.error("PRIVATE_KEY belum di-set!"); process.exit(1); }
  if (!CONFIG.PRIVATE_KEY.startsWith("0x")) CONFIG.PRIVATE_KEY = "0x" + CONFIG.PRIVATE_KEY;

  logger.info(`CPU Threads  : ${CONFIG.CPU_THREADS}`);
  logger.info(`Telegram     : ${CONFIG.TG_BOT_TOKEN ? "✓ Aktif" : "✗ Nonaktif"}`);

  const provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
  const wallet   = new ethers.Wallet(CONFIG.PRIVATE_KEY, provider);
  const contract = new ethers.Contract(CONFIG.CONTRACT_ADDRESS, CONTRACT_ABI, wallet);

  logger.info(`Wallet       : ${wallet.address}`);

  try {
    const block = await provider.getBlockNumber();
    logger.info(`Base block   : #${block}`);
  } catch (e) { logger.error(`RPC error: ${e.message}`); process.exit(1); }

  sendTelegram(
    `🟢 <b>NONCE Miner Dimulai</b>\n\n` +
    `👛 <b>Wallet:</b>\n<code>${wallet.address}</code>\n\n` +
    `🖥️ CPU Threads: <b>${CONFIG.CPU_THREADS}</b>\n` +
    `🌐 RPC: ${CONFIG.RPC_URL}\n` +
    `⏰ ${new Date().toLocaleString("id-ID", { timeZone: "Asia/Jakarta" })} WIB`
  );

  let totalMinted = 0, totalAttempts = 0;
  const sessionStart = Date.now();

  while (true) {
    try {
      const isOpen = await contract.miningOpen();
      if (!isOpen) {
        logger.warn("Mining belum dibuka. Retry 60s...");
        await sleep(60000);
        continue;
      }

      const [challenge, difficultyRaw, reward, mintCount] = await Promise.all([
        contract.getChallenge(wallet.address),
        contract.getMiningDifficulty(),
        contract.getMiningReward(),
        contract.mintCount(),
      ]);

      const difficulty = Number(difficultyRaw);
      const rewardFmt  = ethers.formatUnits(reward, 18);

      logger.info("─────────────────────────────────────────");
      logger.info(`Challenge  : ${challenge}`);
      logger.info(`Difficulty : ${difficulty} | Reward: ${rewardFmt} NONCE | Total mint: ${mintCount}`);
      logger.info("Mining...");

      const solution = await runWorkers(challenge, difficulty);
      if (!solution) { logger.warn("Range habis, refresh..."); continue; }

      totalAttempts++;
      logger.success(`Solusi! nonce=${solution.nonce} | ${fmtH(solution.hashrate)} | ${(solution.elapsed/1000).toFixed(1)}s`);

      logger.info("Submit ke blockchain...");
      try {
        const tx = await contract.mint(BigInt(solution.nonce), {
          gasLimit: CONFIG.GAS_LIMIT,
          gasPrice: ethers.parseUnits(CONFIG.GAS_PRICE_GWEI, "gwei"),
        });
        logger.info(`Tx: ${tx.hash}`);
        const receipt = await tx.wait(1);

        if (receipt.status === 1) {
          totalMinted++;
          const uptime = Math.floor((Date.now() - sessionStart) / 1000);
          let balStr = "?";
          try { balStr = parseFloat(ethers.formatUnits(await contract.balanceOf(wallet.address), 18)).toFixed(2); } catch(_) {}

          logger.success(`✓ MINT #${totalMinted} | Saldo: ${balStr} NONCE | Uptime: ${fmtD(uptime)}`);

          sendTelegram(
            `⛏️ <b>NONCE Berhasil Di-Mine!</b>\n\n` +
            `✅ Mint ke-<b>${totalMinted}</b> sukses!\n\n` +
            `👛 <b>Wallet:</b>\n<code>${wallet.address}</code>\n\n` +
            `🪙 <b>Reward:</b> ${rewardFmt} NONCE\n` +
            `💰 <b>Saldo NONCE:</b> ${balStr} NONCE\n\n` +
            `🔗 <b>Tx Hash:</b>\n<code>${receipt.hash}</code>\n` +
            `🔎 <a href="https://basescan.org/tx/${receipt.hash}">Lihat di BaseScan</a>\n\n` +
            `📊 <b>Statistik Sesi:</b>\n` +
            `• Total mint   : ${totalMinted}\n` +
            `• Total attempt: ${totalAttempts}\n` +
            `• Hashrate     : ${fmtH(solution.hashrate)}\n` +
            `• Waktu solve  : ${(solution.elapsed/1000).toFixed(1)}s\n` +
            `• Uptime       : ${fmtD(uptime)}\n\n` +
            `⏰ ${new Date().toLocaleString("id-ID", { timeZone: "Asia/Jakarta" })} WIB`
          );
        } else {
          logger.error("Tx reverted.");
          sendTelegram(`❌ <b>Transaksi Reverted</b>\n<code>${receipt.hash}</code>`);
        }
      } catch (e) {
        logger.error(`Submit error: ${e.message}`);
        if (e.message.includes("nonce")) await sleep(10000);
      }
    } catch (e) {
      logger.error(`Loop error: ${e.message}`);
      await sleep(CONFIG.RETRY_DELAY_MS);
    }
    await sleep(2000);
  }
}

function runWorkers(challenge, difficulty) {
  return new Promise((resolve) => {
    const threads = CONFIG.CPU_THREADS;
    const RANGE   = 10_000_000;
    const base    = BigInt(Math.floor(Math.random() * 1e15));
    const workers = [];
    let done = 0, solved = false, totH = 0, totR = 0, pc = 0;

    for (let i = 0; i < threads; i++) {
      const w = new Worker(__filename, {
        workerData: { challenge, difficulty, workerId: i, rangeStart: (base + BigInt(i * RANGE)).toString(), rangeSize: RANGE },
      });
      w.on("message", (msg) => {
        if (msg.type === "SOLUTION" && !solved) {
          solved = true;
          workers.forEach((ww) => ww.terminate());
          resolve({ nonce: msg.nonce, hash: msg.hash, hashrate: Math.floor(msg.hashes / (msg.elapsed / 1000)), elapsed: msg.elapsed });
        } else if (msg.type === "PROGRESS") {
          totH += 100_000; totR = (totR * pc + msg.hashrate) / (pc + 1); pc++;
          if (pc % threads === 0) logger.info(`⛏️  ~${fmtH(Math.floor(totR * threads))} | ${totH.toLocaleString()} hashes`);
        } else if (msg.type === "EXHAUSTED") {
          done++;
          if (done >= threads && !solved) resolve(null);
        }
      });
      w.on("error", (e) => logger.error(`Worker ${i}: ${e.message}`));
      workers.push(w);
    }
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const fmtH  = (h)  => h >= 1e6 ? (h/1e6).toFixed(2)+" MH/s" : h >= 1e3 ? (h/1e3).toFixed(2)+" KH/s" : h+" H/s";
const fmtD  = (s)  => `${Math.floor(s/3600)}h ${Math.floor((s%3600)/60)}m ${s%60}s`;

process.on("SIGINT",  () => { logger.info("SIGINT. Bye!"); process.exit(0); });
process.on("SIGTERM", () => { logger.info("SIGTERM. Bye!"); process.exit(0); });
process.on("uncaughtException", (e) => { logger.error(`Uncaught: ${e.message}`); process.exit(1); });

if (isMainThread) main().catch((e) => { logger.error(`Fatal: ${e.message}`); process.exit(1); });
MINERJS

# ── .env ─────────────────────────────────────────────────────
cat > "$INSTALL_DIR/.env" << ENVEOF
# Auto-generated by install.sh
PRIVATE_KEY=${PRIVATE_KEY}
RPC_URL=${RPC_URL}
CPU_THREADS=${CPU_THREADS}
GAS_PRICE_GWEI=0.002
TG_BOT_TOKEN=${TG_BOT_TOKEN}
TG_CHAT_ID=${TG_CHAT_ID}
LOG_FILE=./logs/miner.log
ENVEOF

chmod 600 "$INSTALL_DIR/.env"

# ── STEP 6: NPM INSTALL ──────────────────────────────────────
echo -e "${CYAN}[6/6] Install Node dependencies...${NC}"
cd "$INSTALL_DIR"
npm install --silent 2>/dev/null
echo -e "${GREEN}✓ Dependencies terinstall${NC}"

# ── START MINER ──────────────────────────────────────────────
echo ""
echo -e "${CYAN}🚀 Menjalankan miner dengan PM2...${NC}"
cd "$INSTALL_DIR"
pm2 delete nonce-miner 2>/dev/null || true
pm2 start ecosystem.config.js
pm2 save --force 2>/dev/null

# Setup pm2 startup (best-effort)
PM2_STARTUP=$(pm2 startup 2>&1 | grep "sudo" | tail -1)
if [ -n "$PM2_STARTUP" ]; then
  eval "$PM2_STARTUP" 2>/dev/null || true
  pm2 save --force 2>/dev/null
fi

# ── SELESAI ──────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "╔══════════════════════════════════════════════════╗"
echo "║          ✅  INSTALASI SELESAI!                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  📁 Install dir  : ${CYAN}${INSTALL_DIR}${NC}"
echo -e "  📋 Log file     : ${CYAN}${INSTALL_DIR}/logs/miner.log${NC}"
echo ""
echo -e "${BOLD}Perintah berguna:${NC}"
echo -e "  ${YELLOW}pm2 logs nonce-miner${NC}       ← pantau log realtime"
echo -e "  ${YELLOW}pm2 status${NC}                 ← cek status"
echo -e "  ${YELLOW}pm2 stop nonce-miner${NC}        ← stop miner"
echo -e "  ${YELLOW}pm2 restart nonce-miner${NC}     ← restart miner"
echo -e "  ${YELLOW}tail -f ${INSTALL_DIR}/logs/miner.log${NC}"
echo ""

if [ -n "$TG_BOT_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
  echo -e "  ${GREEN}📱 Telegram notifikasi AKTIF — cek HP kamu!${NC}"
else
  echo -e "  ${YELLOW}📱 Telegram belum dikonfigurasi.${NC}"
  echo -e "     Edit .env: ${CYAN}nano ${INSTALL_DIR}/.env${NC}"
fi

echo ""
echo -e "${CYAN}Miner sedang berjalan. Gunakan 'pm2 logs nonce-miner' untuk memantau.${NC}"
echo ""
