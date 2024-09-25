pragma solidity ^0.8.20;


import "forge-std/Script.sol";
import "forge-std/console.sol";
import {MockCAKE} from "./mocks/mCAKE.sol";
import {MockUSDC} from "./mocks/mUSDC.sol";

contract DeployMockTokens is Script {
    function run() public {

        vm.broadcast();
        address cake = address(new MockCAKE());
        console.log("mCAKE address: ", cake);

        vm.broadcast();
        address usdc = address(new MockUSDC());
        console.log("mUSDC address: ", usdc);
    }
}