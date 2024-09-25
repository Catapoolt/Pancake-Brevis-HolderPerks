// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {HolderPerks} from "../src/pool-cl/HolderPerks.sol";

contract DeployHolderPerks is Script {
    // BNB TESTNET
    address constant CLPOOLMANAGER = 0x969D90aC74A1a5228b66440f8C8326a8dA47A5F9;
    address constant BREVIS_REQUEST = 0xF7E9CB6b7A157c14BCB6E6bcf63c1C7c92E952f5;

    function setUp() public {}

    function run() public {
        vm.broadcast();

        HolderPerks hook = new HolderPerks(CLPOOLMANAGER, BREVIS_REQUEST);
        console.log("Hook address: ", address(hook));
    }
}