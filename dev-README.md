# DIG

## Getting Started

```bash
git clone https://github.com/"git-repo-here"
```

### Install yarn

```bash
npm install -g yarn
```

### Install Dependencies

```bash
# Install Solidity dependencies
forge install

# Install dependencies
yarn install
```

> Make sure you have foundry installed globally. [Get it here](https://book.getfoundry.sh/getting-started/installation).

### Compile

```bash
yarn run compile
```

### Test

```bash
 echo "add test script"
```

### Format Code

```bash
forge fmt
```

## contracts architecture

1. strategy
   - AllocationStrategy
   - BaseStrategy
2. vault
   - Vault
3. GovRoles
4. Pantheon
