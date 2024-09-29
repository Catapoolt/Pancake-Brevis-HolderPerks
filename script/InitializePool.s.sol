pragma solidity ^0.8.20;


import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "pancake-v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "pancake-v4-core/src/types/Currency.sol";
import {IHooks} from "pancake-v4-core/src/interfaces/IHooks.sol";
import {CLPoolParametersHelper} from "pancake-v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";

contract InitializePool is Script {
    using CurrencyLibrary for Currency;
    using CLPoolParametersHelper for bytes32;

    // BNB TESTNET
    address constant CLPOOLMANAGER = 0x969D90aC74A1a5228b66440f8C8326a8dA47A5F9;
    address constant mCAKE = 0x5e799ab7E65bB718B545C76Ac9E6E74fc880a1D0;
    address constant mUSDC = 0x7E421Eee45038D0Ea1aD51Aaf1e5784c4e0765D0;
    address constant HOOK = 0x0e8d3fD384ff2089E9bb7D06Ce37508ab1bcd032;

    ICLPoolManager manager = ICLPoolManager(CLPOOLMANAGER);

    function run() public {
        address token0 = uint160(mUSDC) < uint160(mCAKE) ? mUSDC : mCAKE;
        address token1 = uint160(mUSDC) < uint160(mCAKE) ? mCAKE : mUSDC;
        uint24 swapFee = 4000;

        uint160 startingPrice = 79228162514264337593543950336;
    
        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            poolManager: manager,
            hooks: IHooks(HOOK),
            parameters: bytes32(uint256(IHooks(HOOK).getHooksRegistrationBitmap())).setTickSpacing(10)
        });

        PoolId id = PoolIdLibrary.toId(pool);
        bytes32 idBytes = PoolId.unwrap(id);

        console.log("Pool ID Below");
        console.logBytes32(bytes32(idBytes));

        vm.broadcast();
        manager.initialize(pool, startingPrice, bytes(""));
    }
}