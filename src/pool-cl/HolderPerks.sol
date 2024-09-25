// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "pancake-v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta} from "pancake-v4-core/src/types/BeforeSwapDelta.sol";
import {PoolId, PoolIdLibrary} from "pancake-v4-core/src/types/PoolId.sol";
import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {Currency, CurrencyLibrary} from "pancake-v4-core/src/types/Currency.sol";
import {IERC20Minimal} from "pancake-v4-core/src/interfaces/IERC20Minimal.sol";
import {CLBaseHook} from "./CLBaseHook.sol";
import "brevis-contracts/sdk/apps/framework/BrevisApp.sol";

/// @notice CLCounterHook is a contract that counts the number of times a hook is called
/// @dev note the code is not production ready, it is only to share how a hook looks like
contract HolderPerks is CLBaseHook, BrevisApp {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    error NotEligibleForFees();
    error NoFeesLeftToClaim();

    struct PoolConfig {
        uint256 feeBipsForHolders;
        uint256 interval;
        uint256 startTimestamp;
    }

    struct LPIntervalInfo {
        uint256 share;
        uint256 alreadyClaimed0;
        uint256 alreadyClaimed1;
        uint256 lastTotalCurrency0Fees;
        uint256 lastTotalCurrency1Fees;
    }

    uint128 constant public FEE_BIPS_FOR_HOLDERS = 1000;
    uint256 constant public INTERVAL = 1 days;
    
    bytes32 public vkHash;

    mapping(PoolId => mapping(uint256 => uint256)) public currency0FeesForHolders;
    mapping(PoolId => mapping(uint256 => uint256)) public currency1FeesForHolders;
    mapping(PoolId => mapping(address => mapping(uint256 => LPIntervalInfo))) public lpIntervalInfo;
    mapping(PoolId => uint256) public poolStartTimestamp;

    constructor(
        address _poolManager,
        address _brevisRequest
    ) CLBaseHook(ICLPoolManager(_poolManager)) BrevisApp(_brevisRequest) {}

    
    function handleProofResult(
        bytes32 _vkHash,
        bytes calldata _appCircuitOutput
    ) internal override {
        require(vkHash == _vkHash, "invalid vk");

        (
            uint256 share,
            PoolId poolId,
            address liquidityProvider, 
            uint256 periodId
        ) = decodeOutput(_appCircuitOutput);

        LPIntervalInfo storage info = lpIntervalInfo[poolId][liquidityProvider][periodId];
        info.share = share;
    }

    function decodeOutput(bytes calldata output) internal pure returns(
        uint256 share,
        PoolId poolId,
        address liquidityProvider, 
        uint256 periodId
    ) {
        (share, poolId, liquidityProvider, periodId) = abi.decode(output, (uint256, PoolId, address, uint256));
    }

    function withdrawHolderFees(PoolKey calldata key, uint256 interval, uint256 amount0, uint256 amount1) external {
        address liquidityProvider = msg.sender;
        PoolId poolId = key.toId();
        LPIntervalInfo storage info = lpIntervalInfo[poolId][liquidityProvider][interval];

        if(info.share == 0) revert NotEligibleForFees();

        if(amount0 > 0) {
            uint256 currency0Fees = currency0FeesForHolders[poolId][interval];

            if(currency0Fees > 0) {
                uint256 feesToClaimFrom;

                if(info.lastTotalCurrency0Fees == 0) {
                    feesToClaimFrom = currency0Fees;
                } else if(info.lastTotalCurrency0Fees < currency0Fees) {
                    feesToClaimFrom = currency0Fees - info.lastTotalCurrency0Fees;
                } else {
                    revert NoFeesLeftToClaim();
                }

                uint256 toReceive0 = feesToClaimFrom / info.share;

                IERC20Minimal(Currency.unwrap(key.currency0)).transfer(msg.sender, toReceive0);
            }
        }
        
        if(amount1 > 0) {
            uint256 currency1Fees = currency1FeesForHolders[poolId][interval];

            if(currency1Fees > 0) {
                uint256 feesToClaimFrom;

                if(info.lastTotalCurrency1Fees == 0) {
                    feesToClaimFrom = currency1Fees;
                } else if(info.lastTotalCurrency1Fees < currency1Fees) {
                    feesToClaimFrom = currency1Fees - info.lastTotalCurrency1Fees;
                } else {
                    revert NoFeesLeftToClaim();
                }

                uint256 toReceive1 = feesToClaimFrom / info.share;

                IERC20Minimal(Currency.unwrap(key.currency1)).transfer(msg.sender, toReceive1);
            }
        }
        
    }

    function getHooksRegistrationBitmap() external pure override returns (uint16) {
        return _hooksRegistrationBitmapFrom(
            Permissions({
                beforeInitialize: true,
                afterInitialize: false,
                beforeAddLiquidity: true,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnsDelta: true,
                afterSwapReturnsDelta: false,
                afterAddLiquidityReturnsDelta: false,
                afterRemoveLiquidityReturnsDelta: false
            })
        );
    }

    function beforeInitialize(address, PoolKey calldata key, uint160, bytes calldata)
        external
        override
        returns (bytes4) {
            poolStartTimestamp[key.toId()] = block.timestamp;

            return CLBaseHook.afterInitialize.selector;
    }

    function beforeSwap(address, PoolKey calldata key, ICLPoolManager.SwapParams calldata params, bytes calldata)
        external
        override
        poolManagerOnly
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        int128 amountSpecified = int128(params.amountSpecified);

        uint128 swapAmount = amountSpecified > 0 ? uint128(amountSpecified)
            : uint128(-amountSpecified);

        uint128 feeForHolders = swapAmount * FEE_BIPS_FOR_HOLDERS / 1_000_000;

        PoolId poolId = key.toId();

        if(params.zeroForOne) {
            currency0FeesForHolders[poolId][(block.timestamp - poolStartTimestamp[poolId]) / INTERVAL] += feeForHolders;
        } else {
            currency1FeesForHolders[key.toId()][(block.timestamp - poolStartTimestamp[poolId]) / INTERVAL] += feeForHolders;
        }

        Currency input = params.zeroForOne ? key.currency0 : key.currency1;
        vault.take(input, address(this), uint256(feeForHolders));

        return (CLBaseHook.beforeSwap.selector, toBeforeSwapDelta(int128(feeForHolders), 0), 0);
    }
}
