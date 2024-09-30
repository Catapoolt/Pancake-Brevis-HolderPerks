# HolderPerks

HolderPerks is a Pancakeswap V4 hook contract that allows liquidity providers to earn additional swap fees
based on holding a certain token. Brevis is used to compute a holding power based on
the amount of tokens held per block during the pre-configured time interval set at
pool initialization. The user requests the proof for each such period that dictates
the share it will receive from the fees generated for token holders. After Brevis fulfills the request,
the user is able to claim these fees with each swap happening in that time interval.

## Prerequisite

Install foundry, see https://book.getfoundry.sh/getting-started/installation

## Dependencies

Install dependencies with `forge install`

## Testing on-chain using scripts

We assume we conduct the testing flow on Binance Smart Chain Testnet.
In the next steps when running scripts, you should replace the placeholders
with a suitable corresponding BNB Testnet RPC URL and private key that has
tBNB funds.

1. The first step is to deploy the HolderPerks hook using the "DeployHolderPerks.s.sol" script.
Run the following command:

```
forge script script/DeployHolderPerks.s.sol \
--rpc-url [your_rpc_url_here] \
--private-key [your_private_key]
--broadcast
```

Extract the logged hook address and replace it in all files inside the
"script" directory where the following address variable appears:

```solidity
address constant HOOK = ...;
```

2. Following the hook deployment, we need to create mock tokens
using the following script:

```
forge script script/DeployMockTokens.s.sol \
--rpc-url [your_rpc_url_here] \
--private-key [your_private_key]
--broadcast
```

Extract the logged addresses and replace the existing ones
in all script files where the following addresses appear:

```solidity
address constant mCAKE = ...;
address constant mUSDC = ...;
```

3. Next step is to initialize the pool with our mock tokens
as the underlying pair:

```
forge script script/InitializePool.s.sol \
--rpc-url [your_rpc_url_here] \
--private-key [your_private_key]
--broadcast
```

The logged Pool ID needs to be replaced in the scripts file
where the following variable is declared:

```solidity
 PoolId public POOL_ID = PoolId.wrap(...);
```

4. Now we need to add liquidity to our pool using the following command:

```
forge script script/AddLiquidity.s.sol \
--rpc-url [your_rpc_url_here] \
--private-key [your_private_key]
--broadcast
```

5. After the liquidity was added, we can perform a swap to generate holder fees.
Before that, replace the following line in the "Swap.s.sol" script
with the address public address used to run the scripts:

```solidity
address constant recipient = ...;
```

Now run:

```
forge script script/Swap.s.sol \
--rpc-url [your_rpc_url_here] \
--private-key [your_private_key]
--broadcast
```

6. Before withdrawing the holder fees, we will first call a mock function
to simulate Brevis pushing the data containing the fees share. But first,
replace the following line in the "MockHandleProofResult.s.sol" script
with the address public address used to run the scripts:

```solidity
address constant LIQ_PROVIDER = ...;
```

Then run:

```
forge script script/Swap.s.sol \
--rpc-url [your_rpc_url_here] \
--private-key [your_private_key]
--broadcast
```

7. We can finally run the script for withdrawing the generated holder fees:

```
forge script script/WithdrawHolderFees.s.sol \
--rpc-url [your_rpc_url_here] \
--private-key [your_private_key]
--broadcast
```

Taking the TxHash to a BNB Testnet explorer, you should see that the fees were
credited to your address.