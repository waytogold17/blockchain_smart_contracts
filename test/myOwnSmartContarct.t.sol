// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/myOwnSmartContarct.sol";
import "../src/MockERC20.sol";
import "../src/MockNFT.sol"; // Assurez-vous d'avoir créé ce fichier (étape 1)

contract MemberVestingTest is Test {
    MemberVesting public vestingContract;
    MockERC20 public rewardToken;
    MockNFT public nftCollection;

    address public owner;
    address public alice;
    address public bob;

    uint256 public constant TOKEN_ID = 1; // On va tester avec le NFT #1
    uint256 public constant TOTAL_REWARD = 1000 ether;
    uint256 public constant DURATION = 100 days;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice"); // Crée une fausse adresse pour Alice
        bob = makeAddr("bob");     // Crée une fausse adresse pour Bob

        // 1. Déploiement des contrats
        rewardToken = new MockERC20();
        nftCollection = new MockNFT();
        vestingContract = new MemberVesting(address(rewardToken), address(nftCollection));

        // 2. Préparation des fonds (Reward Token)
        rewardToken.mint(owner, TOTAL_REWARD);
        rewardToken.approve(address(vestingContract), TOTAL_REWARD);

        // 3. Distribution du NFT (Alice reçoit le NFT #1)
        nftCollection.mint(alice, TOKEN_ID);
    }

    // Test 1 : Vérifier que le vesting est bien créé
    function test_AddVesting() public {
        vestingContract.addVestingForNFT(TOKEN_ID, TOTAL_REWARD, DURATION);

        // Vérifie que le contrat a bien pris les fonds
        assertEq(rewardToken.balanceOf(address(vestingContract)), TOTAL_REWARD);
        
        // Vérifie les données
        uint256 claimable = vestingContract.getClaimableAmount(TOKEN_ID);
        assertEq(claimable, 0); // 0 car le temps n'a pas avancé
    }

    // Test 2 : Alice réclame normalement (Sans vente)
    function test_AliceClaimNormal() public {
        // Setup du vesting
        vestingContract.addVestingForNFT(TOKEN_ID, TOTAL_REWARD, DURATION);

        // On avance à 50% du temps
        vm.warp(block.timestamp + (DURATION / 2));

        // Alice (propriétaire du NFT) réclame
        vm.startPrank(alice);
        vestingContract.claim(TOKEN_ID);
        vm.stopPrank();

        // Elle doit avoir reçu 50% (500 tokens)
        assertEq(rewardToken.balanceOf(alice), TOTAL_REWARD / 2);
    }

    // Test 3 : SCÉNARIO CLÉ - Transfert du NFT (Alice -> Bob)
    function test_VestingFollowsNFT() public {
        // 1. Le Owner configure le vesting pour le NFT #1
        vestingContract.addVestingForNFT(TOKEN_ID, TOTAL_REWARD, DURATION);

        // 2. Le temps passe (50% écoulé)
        vm.warp(block.timestamp + (DURATION / 2));

        // --- MOMENT CRITIQUE : Alice vend son NFT à Bob ---
        vm.prank(alice);
        nftCollection.transferFrom(alice, bob, TOKEN_ID);

        // Vérification : Bob est bien le nouveau propriétaire
        assertEq(nftCollection.ownerOf(TOKEN_ID), bob);

        // 3. Alice essaie de réclamer ses gains passés...
        vm.startPrank(alice);
        vm.expectRevert("Tu ne possedes pas ce NFT !"); // Le contrat doit la bloquer
        vestingContract.claim(TOKEN_ID);
        vm.stopPrank();

        // 4. Bob réclame (il a acheté le NFT, il a droit au vesting associé)
        vm.startPrank(bob);
        vestingContract.claim(TOKEN_ID);
        vm.stopPrank();

        // 5. Vérification finale
        // Bob doit avoir reçu les 500 tokens accumulés
        assertEq(rewardToken.balanceOf(bob), TOTAL_REWARD / 2);
        // Alice a 0 token (elle a vendu trop tôt !)
        assertEq(rewardToken.balanceOf(alice), 0);
    }

    // Test 4 : Personne ne peut voler le vesting d'un autre
    function test_UnauthorizedClaim() public {
        vestingContract.addVestingForNFT(TOKEN_ID, TOTAL_REWARD, DURATION);
        vm.warp(block.timestamp + DURATION); // Tout est débloqué

        // Bob (qui n'a pas le NFT) essaie de réclamer
        vm.startPrank(bob);
        vm.expectRevert("Tu ne possedes pas ce NFT !");
        vestingContract.claim(TOKEN_ID);
        vm.stopPrank();
    }
}