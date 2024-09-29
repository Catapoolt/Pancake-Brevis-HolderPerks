pragma solidity ^0.8.20;

import {HolderPerks} from "../src/pool-cl/HolderPerks.sol";
import {Script, console} from "forge-std/Script.sol";
import {PoolId, PoolIdLibrary} from "pancake-v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "pancake-v4-core/src/types/Currency.sol";
import {CLPoolParametersHelper} from "pancake-v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {IHooks} from "pancake-v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";

contract WithdrawHolderFees is Script {
    using CurrencyLibrary for Currency;
    using CLPoolParametersHelper for bytes32;
    using PoolIdLibrary for PoolKey;

    address constant public HOOK = 0x0e8d3fD384ff2089E9bb7D06Ce37508ab1bcd032;
    PoolId public POOL_ID = PoolId.wrap(0x799c3636388fbce2486e645f3d3cdf7f0832657a2730192cf1700cfd670e61fb);
    uint256 constant public SHARE = 10;
    uint256 constant public PERIOD_ID = 0;
    address constant public LIQ_PROVIDER = 0x3195ee2A3c4Cc67f448767faAdb061472e670223;

    address constant mCAKE = 0x5e799ab7E65bB718B545C76Ac9E6E74fc880a1D0;
    address constant mUSDC = 0x7E421Eee45038D0Ea1aD51Aaf1e5784c4e0765D0;
    uint24 constant swapFee = 4000;
    address constant CLPOOLMANAGER = 0x969D90aC74A1a5228b66440f8C8326a8dA47A5F9;

    function run() public {
        address token0 = uint160(mUSDC) < uint160(mCAKE) ? mUSDC : mCAKE;
        address token1 = uint160(mUSDC) < uint160(mCAKE) ? mCAKE : mUSDC;

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            poolManager: ICLPoolManager(CLPOOLMANAGER),
            hooks: IHooks(HOOK),
            parameters: bytes32(uint256(IHooks(HOOK).getHooksRegistrationBitmap())).setTickSpacing(10)
        });

        vm.broadcast();
        HolderPerks(HOOK).withdrawHolderFees(key, 0, true, false);
    }
}