// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/VestingWallet.sol";
import "../src/MockToken.sol";

contract DeployVestingWallet is Script {
    function run() external {
        // On récupère la clé privée du fichier .env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Début de la transaction (tout ce qui suit est payant en gas)
        vm.startBroadcast(deployerPrivateKey);

        // 1. Déploiement du Jeton
        MockToken token = new MockToken();
        console.log("Token deployed at:", address(token));

        // 2. Déploiement du VestingWallet (en lui donnant l'adresse du jeton)
        VestingWallet wallet = new VestingWallet(address(token));
        console.log("VestingWallet deployed at:", address(wallet));

        vm.stopBroadcast();
    }
}
