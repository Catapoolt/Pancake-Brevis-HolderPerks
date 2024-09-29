import {PositionConfig} from "pancake-v4-periphery/src/pool-cl/libraries/PositionConfig.sol";
import {Planner, Plan} from "pancake-v4-periphery/src/libraries/Planner.sol";
import {Actions} from "pancake-v4-periphery/src/libraries/Actions.sol";
import {Script, console} from "forge-std/Script.sol";
import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {IERC20Minimal} from "pancake-v4-core/src/interfaces/IERC20Minimal.sol";
import {ICLPositionManager} from "pancake-v4-periphery/src/pool-cl/interfaces/ICLPositionManager.sol";
import {LiquidityAmounts} from "pancake-v4-periphery/src/pool-cl/libraries/LiquidityAmounts.sol";
import {TickMath} from "pancake-v4-core/src/pool-cl/libraries/TickMath.sol";
import {IHooks} from "pancake-v4-core/src/interfaces/IHooks.sol";
import {Currency, CurrencyLibrary} from "pancake-v4-core/src/types/Currency.sol";
import {CLPoolParametersHelper} from "pancake-v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {PoolId, PoolIdLibrary} from "pancake-v4-core/src/types/PoolId.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

contract AddLiquidity is Script {
    using CurrencyLibrary for Currency;
    using CLPoolParametersHelper for bytes32;
    using PoolIdLibrary for PoolKey;
    using Planner for Plan;

    address constant CLPOOLMANAGER = 0x969D90aC74A1a5228b66440f8C8326a8dA47A5F9;
    address constant mCAKE = 0x5e799ab7E65bB718B545C76Ac9E6E74fc880a1D0;
    address constant mUSDC = 0x7E421Eee45038D0Ea1aD51Aaf1e5784c4e0765D0;
    address constant CL_POSITION_MANAGER = 0x89A7D45D007077485CB5aE2abFB740b1fe4FF574;
    address constant HOOK = 0x0e8d3fD384ff2089E9bb7D06Ce37508ab1bcd032;
    address constant PERMIT2 = 0x31c2F6fcFf4F8759b3Bd5Bf0e1084A055615c768;
    
    ICLPoolManager constant poolManager = ICLPoolManager(CLPOOLMANAGER);
    ICLPositionManager constant positionManager = ICLPositionManager(CL_POSITION_MANAGER);

    function run() public {
        address token0 = uint160(mUSDC) < uint160(mCAKE) ? mUSDC : mCAKE;
        address token1 = uint160(mUSDC) < uint160(mCAKE) ? mCAKE : mUSDC;
        uint24 swapFee = 4000;
        
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            poolManager: poolManager,
            hooks: IHooks(HOOK),
            parameters: bytes32(uint256(IHooks(HOOK).getHooksRegistrationBitmap())).setTickSpacing(10)
        });

        uint128 amount0Max = 1 ether;
        uint128 amount1Max = 1 ether;
        int24 tickLower = -120;
        int24 tickUpper = 120;
        address recipient = 0x3195ee2A3c4Cc67f448767faAdb061472e670223;

        if(IERC20Minimal(token0).allowance(recipient, PERMIT2) == 0){
             vm.broadcast();
             IERC20Minimal(token0).approve(PERMIT2, type(uint256).max);
        }

        if(IERC20Minimal(token1).allowance(recipient, PERMIT2) == 0) {
            vm.broadcast();
            IERC20Minimal(token1).approve(PERMIT2, type(uint256).max);
        }

        IAllowanceTransfer permit2 = IAllowanceTransfer(PERMIT2);

        (uint160 allowance0, ,) = permit2.allowance(recipient, token0, CL_POSITION_MANAGER);
        if(allowance0 == 0) {
            vm.broadcast();
            permit2.approve(token0, CL_POSITION_MANAGER, type(uint160).max, type(uint48).max);
        }

        (uint160 allowance1, ,) = permit2.allowance(recipient, token1, CL_POSITION_MANAGER);
        if(allowance1 == 0) {
            vm.broadcast();
            permit2.approve(token1, CL_POSITION_MANAGER, type(uint160).max, type(uint48).max);
        }

        vm.startBroadcast();
        uint256 tokenId = addLiquidity(key, amount0Max, amount1Max, tickLower, tickUpper, recipient);
        vm.stopBroadcast();
        console.log("Added liquidity. Returned token ID:", tokenId);
    }

    function addLiquidity(
        PoolKey memory key,
        uint128 amount0Max,
        uint128 amount1Max,
        int24 tickLower,
        int24 tickUpper,
        address recipient
    ) internal returns (uint256 tokenId) {
        tokenId = positionManager.nextTokenId();

        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(key.toId());
        uint256 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            amount0Max,
            amount1Max
        );
        PositionConfig memory config = PositionConfig({poolKey: key, tickLower: tickLower, tickUpper: tickUpper});
        Plan memory planner = Planner.init().add(
            Actions.CL_MINT_POSITION, abi.encode(config, liquidity, amount0Max, amount1Max, recipient, new bytes(0))
        );
        bytes memory data = planner.finalizeModifyLiquidityWithClose(key);
        positionManager.modifyLiquidities(data, block.timestamp + 300);
    }
}