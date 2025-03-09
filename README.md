```markdown
# Foundry Raffle Project

A Solidity smart contract project for a decentralized raffle system using Foundry and Chainlink VRF.

## Features
- Raffle ticket purchase with ETH
- Chainlink VRF for verifiable randomness
- Automated winner selection
- Multi-network deployment support
- Comprehensive test coverage

## 🚀 Getting Started

### Prerequisites
- [Foundry](https://getfoundry.sh) (version ≥ 0.2.0)
- Node.js (version ≥ 16.x)
- Git

### Installation
1. Clone the repository:
```bash
git clone https://github.com/your-username/foundry-raffle.git
cd foundry-raffle
```

2. Install dependencies:
```bash
make install
```

## 🔧 Configuration

1. Copy environment template:
```bash
cp .env.example .env
```

2. Edit `.env` with your credentials:
```ini
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-key
PRIVATE_KEY=0xyour-private-key
ETHERSCAN_API_KEY=your-etherscan-key
```

## 📜 Available Commands

| Command                | Description                                  |
|------------------------|----------------------------------------------|
| `make all`             | Clean, install deps, and build              |
| `make test`            | Run all tests                                |
| `make deploy`          | Deploy to specified network                  |
| `make anvil`           | Start local Anvil node                       |
| `make format`          | Format Solidity code                         |
| `make clean`           | Clean build artifacts                        |
| `make snapshot`        | Create test coverage snapshot                |

## 🌐 Deployment

### Local Development
1. Start Anvil node:
```bash
make anvil
```

2. Deploy locally:
```bash
make deploy
```

### Sepolia Testnet
```bash
make deploy ARGS="--network sepolia"
```

## 🔗 Chainlink VRF Setup

1. Create subscription:
```bash
make createSubscription ARGS="--network sepolia"
```

2. Add contract as consumer:
```bash
make addConsumer ARGS="--network sepolia"
```

3. Fund subscription:
```bash
make fundSubscription ARGS="--network sepolia"
```

## 🧪 Testing
Run comprehensive test suite:
```bash
make test
```

Generate test coverage report:
```bash
make snapshot
```

## ⚠️ Important Notes
1. Always keep your `.env` file private
2. Ensure VRF subscription has sufficient LINK balance
3. Mainnet deployments require contract verification
4. Recommended gas limit for VRF: 2500000 wei

## 📄 License
MIT License - see [LICENSE](LICENSE) for details
```

