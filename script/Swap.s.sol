import {Script, console} from "forge-std/Script.sol";
import {Planner, Plan} from "pancake-v4-periphery/src/libraries/Planner.sol";
import {Actions} from "pancake-v4-periphery/src/libraries/Actions.sol";
import {UniversalRouter, RouterParameters} from "pancake-v4-universal-router/src/UniversalRouter.sol";
import {ICLRouterBase} from "pancake-v4-periphery/src/pool-cl/interfaces/ICLRouterBase.sol";
import {Commands} from "pancake-v4-universal-router/src/libraries/Commands.sol";
import {ICLPoolManager} from "pancake-v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {PoolKey} from "pancake-v4-core/src/types/PoolKey.sol";
import {ActionConstants} from "pancake-v4-periphery/src/libraries/ActionConstants.sol";
import {IHooks} from "pancake-v4-core/src/interfaces/IHooks.sol";
import {Currency, CurrencyLibrary} from "pancake-v4-core/src/types/Currency.sol";
import {CLPoolParametersHelper} from "pancake-v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {PoolId, PoolIdLibrary} from "pancake-v4-core/src/types/PoolId.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

contract Swap is Script {
    using CurrencyLibrary for Currency;
    using CLPoolParametersHelper for bytes32;
    using PoolIdLibrary for PoolKey;
    using Planner for Plan;

    UniversalRouter constant UNVIVERSAL_ROUTER = UniversalRouter(payable(0x30067B296Edf5BEbB1CB7b593898794DDF6ab7c5));
    address constant CLPOOLMANAGER = 0x969D90aC74A1a5228b66440f8C8326a8dA47A5F9;
    address constant mCAKE = 0x5e799ab7E65bB718B545C76Ac9E6E74fc880a1D0;
    address constant mUSDC = 0x7E421Eee45038D0Ea1aD51Aaf1e5784c4e0765D0;
    address constant HOOK = 0x0e8d3fD384ff2089E9bb7D06Ce37508ab1bcd032;
    address constant PERMIT2 = 0x31c2F6fcFf4F8759b3Bd5Bf0e1084A055615c768;
    address constant recipient = 0x3195ee2A3c4Cc67f448767faAdb061472e670223;

    ICLPoolManager manager = ICLPoolManager(CLPOOLMANAGER);

    function run() public {
        address token0 = uint160(mUSDC) < uint160(mCAKE) ? mUSDC : mCAKE;
        address token1 = uint160(mUSDC) < uint160(mCAKE) ? mCAKE : mUSDC;
        uint24 swapFee = 4000;
        
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            poolManager: manager,
            hooks: IHooks(HOOK),
            parameters: bytes32(uint256(IHooks(HOOK).getHooksRegistrationBitmap())).setTickSpacing(10)
        });

        IAllowanceTransfer permit2 = IAllowanceTransfer(PERMIT2);

        (uint160 allowance0, ,) = permit2.allowance(recipient, token0, address(UNVIVERSAL_ROUTER));
        if(allowance0 == 0) {
            vm.broadcast();
            permit2.approve(token0, address(UNVIVERSAL_ROUTER), type(uint160).max, type(uint48).max);
        }

        (uint160 allowance1, ,) = permit2.allowance(recipient, token1, address(UNVIVERSAL_ROUTER));
        if(allowance1 == 0) {
            vm.broadcast();
            permit2.approve(token1, address(UNVIVERSAL_ROUTER), type(uint160).max, type(uint48).max);
        }

         exactInputSingle(
            ICLRouterBase.CLSwapExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,
                amountIn: 0.1 ether,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0,
                hookData: new bytes(0)
            })
        );
    }

    function exactInputSingle(ICLRouterBase.CLSwapExactInputSingleParams memory params) internal {
        Plan memory plan = Planner.init().add(Actions.CL_SWAP_EXACT_IN_SINGLE, abi.encode(params));
        bytes memory data = params.zeroForOne
            ? plan.finalizeSwap(params.poolKey.currency0, params.poolKey.currency1, ActionConstants.MSG_SENDER)
            : plan.finalizeSwap(params.poolKey.currency1, params.poolKey.currency0, ActionConstants.MSG_SENDER);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V4_SWAP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = data;

        vm.broadcast();
        UNVIVERSAL_ROUTER.execute(commands, inputs);
    }
}