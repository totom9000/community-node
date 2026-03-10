# PoolDaemon Community Node

A lightweight stratum relay for [PoolDaemon](https://pooldeamon.com). Earn **80% of pool fees** from miners that connect through your node.

## Setup

1. Register at [pooldeamon.com/community-nodes](https://pooldeamon.com/community-nodes)
2. Wait for approval email with your API key
3. Run:

```bash
git clone https://github.com/totom9000/community-node.git
cd community-node
sudo ./setup.sh
```

The setup script installs WireGuard + socat, connects the VPN tunnel, and starts relay services. No Docker needed.

## Supported Coins

| Coin | Port |
|------|------|
| OctaSpace (OCTA) | 3333 |
| Aves (AVS) | 3334 |
| BitcoinII (BC2) | 3335 |
| Larissa (LRS) | 3337 |

## Management

```bash
sudo systemctl status pooldeamon-3333     # Check status
sudo journalctl -u pooldeamon-3333 -f     # View logs
sudo systemctl restart pooldeamon-3333    # Restart one coin
sudo systemctl stop pooldeamon-3333       # Stop one coin
```

## Firewall

```bash
sudo ufw allow 3333/tcp  # OctaSpace
sudo ufw allow 3334/tcp  # Aves
sudo ufw allow 3335/tcp  # BitcoinII
sudo ufw allow 3337/tcp  # Larissa
```

## Requirements

- Linux (Ubuntu/Debian/Raspbian/Fedora)
- Public IP or port forwarding on ports 3333-3337
- Outbound UDP port 51820 (WireGuard)
