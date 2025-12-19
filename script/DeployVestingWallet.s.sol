// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/VestingWallet.sol";
import "../src/MockERC20.sol";

contract DeployVestingWallet is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // --- CONFIGURATION ---
        // Option A : Mettez une adresse ici pour utiliser un jeton existant (ex: WETH sur Sepolia)
        // Option B : Laissez address(0) pour déployer un NOUVEAU MockToken
        address existingTokenAddress = address(0); 
        
        // Exemples d'adresses WETH connues :
        // Sepolia WETH: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14
        
        address finalTokenAddress;

        // --- LOGIQUE DE SÉLECTION ---
        if (existingTokenAddress != address(0)) {
            // Cas 1 : On utilise un jeton existant
            console.log("Utilisation du token existant a l'adresse :", existingTokenAddress);
            finalTokenAddress = existingTokenAddress;
        } else {
            // Cas 2 : On déploie un nouveau MockToken (votre code actuel)
            MockERC20 token = new MockERC20();
            console.log("Nouveau MockToken deploye a l'adresse :", address(token));
            finalTokenAddress = address(token);
        }

        // --- DÉPLOIEMENT DU WALLET ---
        VestingWallet wallet = new VestingWallet(finalTokenAddress);
        console.log("VestingWallet deploye a l'adresse :", address(wallet));

        vm.stopBroadcast();
    }
}