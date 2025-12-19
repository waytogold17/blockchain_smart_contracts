// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/myOwnSmartContract.sol";
import "../src/MockERC20.sol";
import "../src/MockNFT.sol";

contract DeployMemberVesting is Script {
    function run() external {
        // 1. Récupération de la clé privée
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 2. Démarrage de la transaction
        vm.startBroadcast(deployerPrivateKey);

        // --- ÉTAPE A : Déploiement des Mocks (Les Dépendances) ---
        // On crée notre propre monnaie pour le test
        MockERC20 token = new MockERC20();
        console.log("1. Reward Token deploye a :", address(token));

        // On crée notre propre collection NFT
        MockNFT nft = new MockNFT();
        console.log("2. NFT Collection deploye a :", address(nft));

        // --- ÉTAPE B : Déploiement du MemberVesting ---
        // On passe les adresses des contrats qu'on vient de créer
        MemberVesting vesting = new MemberVesting(address(token), address(nft));
        console.log("3. MemberVesting deploye a :", address(vesting));

        // --- ÉTAPE C : Configuration Initiale (Pour faciliter tes tests manuels) ---
        // Le script va aussi "préparer le terrain" sur la blockchain :
        
        // 1. Mint des tokens au déployeur (toi) pour que tu aies de quoi financer le vesting
        token.mint(vm.addr(deployerPrivateKey), 10000 ether);
        
        // 2. Mint du NFT #1 à toi-même (pour que tu puisses tester le claim)
        nft.mint(vm.addr(deployerPrivateKey), 1);
        
        // 3. Approve : Tu autorises le vesting à prendre tes tokens (préparation)
        token.approve(address(vesting), 10000 ether);

        console.log("--- Configuration terminee : Tu as le NFT #1 et des Tokens ---");

        vm.stopBroadcast();
    }
}