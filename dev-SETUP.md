# _DIG_

---

## Setup

```
$ git clone https://github.com/sudotx/DIG
$ forge install
$ yarn install
$ touch .env
```

Now, edit the `.env` file to contain `ETH_RPC_MAINNET` url for forking.

For example:

```
ETH_RPC_MAINNET=https://eth-mainnet.g.alchemy.com/v2/demo/
```

If using alchemy as above, the `demo` needs to be replaced with your api key to properly run tests.
