// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VestingWallet.sol";
import "../src/MockERC20.sol";

contract VestingWalletTest is Test {
    VestingWallet public vestingWallet;
    MockERC20 public token;

    address public owner;
    address public beneficiary;

    uint256 public constant TOTAL_AMOUNT = 1000 ether;
    uint256 public constant CLIFF = 1 weeks;
    uint256 public constant DURATION = 4 weeks;

    // Cette fonction s'exécute AVANT chaque test
    function setUp() public {
        owner = address(this); // Le contrat de test est le propriétaire
        beneficiary = address(0x123); // Une fausse adresse pour l'employé

        // 1. Déployer le Token et le Wallet
        token = new MockERC20();
        vestingWallet = new VestingWallet(address(token));

        // 2. Se donner des tokens (au contrat de test)
        token.mint(owner, TOTAL_AMOUNT * 10);

        // 3. APPROUVER le VestingWallet à dépenser nos tokens
        // C'est l'étape cruciale souvent oubliée !
        token.approve(address(vestingWallet), TOTAL_AMOUNT);
    }

    function test_CreateSchedule() public {
        // On crée le calendrier
        vestingWallet.createVestingSchedule(beneficiary, TOTAL_AMOUNT, CLIFF, DURATION);

        // Vérification : Le wallet a bien reçu les fonds
        assertEq(token.balanceOf(address(vestingWallet)), TOTAL_AMOUNT);

        // Vérification : La struct est bien initialisée
        (address _benef, , , , uint256 _total, , bool _init) = vestingWallet.vestingSchedules(beneficiary);
        
        assertEq(_benef, beneficiary);
        assertEq(_total, TOTAL_AMOUNT);
        assertTrue(_init);
    }

    function test_RevertBeforeCliff() public {
        vestingWallet.createVestingSchedule(beneficiary, TOTAL_AMOUNT, CLIFF, DURATION);

        // On avance le temps (Time Travel) mais PAS assez pour passer le cliff
        vm.warp(block.timestamp + CLIFF - 1 seconds);

        // On se fait passer pour le bénéficiaire (prank)
        vm.startPrank(beneficiary);
        
        // On s'attend à ce que la prochaine ligne échoue (revert)
        vm.expectRevert("Cliff not reached");
        vestingWallet.claimVestedTokens();
        
        vm.stopPrank();
    }

    function test_ClaimPartialAfterCliff() public {
        vestingWallet.createVestingSchedule(beneficiary, TOTAL_AMOUNT, CLIFF, DURATION);

        // On avance à la moitié du vesting (2 semaines sur 4)
        // 50% du temps écoulé = 50% des tokens débloqués
        vm.warp(block.timestamp + (DURATION / 2));

        // Calcul attendu : 500 tokens
        uint256 expectedAmount = TOTAL_AMOUNT / 2;

        vm.startPrank(beneficiary);
        vestingWallet.claimVestedTokens();
        vm.stopPrank();

        // Vérifie que le bénéficiaire a bien reçu ses tokens
        assertEq(token.balanceOf(beneficiary), expectedAmount);
    }

    function test_ClaimAllAfterDuration() public {
        vestingWallet.createVestingSchedule(beneficiary, TOTAL_AMOUNT, CLIFF, DURATION);

        // On avance APRES la fin totale
        vm.warp(block.timestamp + DURATION + 1 seconds);

        vm.startPrank(beneficiary);
        vestingWallet.claimVestedTokens();
        vm.stopPrank();

        // Il doit avoir tout reçu
        assertEq(token.balanceOf(beneficiary), TOTAL_AMOUNT);
    }
}