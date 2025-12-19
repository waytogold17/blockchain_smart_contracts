// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// On importe les interfaces pour "parler" aux standards
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MemberVesting is Ownable, ReentrancyGuard {

    // --- INTERFACES ---
    // Le jeton qu'on distribue (erc20)
    IERC20 public immutable rewardToken;
    // La collection NFT qui sert de "Clé" d'accès
    IERC721 public immutable membershipNft;

    // --- STRUCT ---
    struct VestingInfo {
        uint256 totalAllocation; // Montant total alloué à ce NFT
        uint256 releasedAmount;  // Montant déjà retiré
        uint256 startTime;       // Début du vesting
        uint256 duration;        // Durée (ex: 1 an)
    }

    // --- MAPPING ---
    // Au lieu de mapping(address => ...), on map le TOKEN_ID du NFT
    // ID du NFT => Infos de vesting
    mapping(uint256 => VestingInfo) public vestingSchedules;

    // --- EVENTS ---
    event VestingAdded(uint256 indexed tokenId, uint256 amount);
    event TokensClaimed(uint256 indexed tokenId, address indexed claimer, uint256 amount);

    constructor(address _rewardToken, address _membershipNft) Ownable(msg.sender) {
        rewardToken = IERC20(_rewardToken);
        membershipNft = IERC721(_membershipNft);
    }

    /**
     * @dev Le Owner ajoute du vesting pour un NFT spécifique (ID).
     * Ex: Le NFT #10 reçoit 1000 tokens bloqués sur 30 jours.
     */
    function addVestingForNFT(
        uint256 _tokenId, 
        uint256 _amount, 
        uint256 _duration
    ) external onlyOwner {
        // Transfert des fonds du Owner vers le contrat (Le "Lock")
        require(rewardToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        VestingInfo storage schedule = vestingSchedules[_tokenId];

        // Si c'est la première fois, on initialise
        if (schedule.totalAllocation == 0) {
            schedule.startTime = block.timestamp;
            schedule.duration = _duration;
        }

        // On ajoute le montant au pot
        schedule.totalAllocation += _amount;

        emit VestingAdded(_tokenId, _amount);
    }

    /**
     * @dev Fonction principale : Réclamer les gains.
     * Accessible UNIQUEMENT si tu possèdes le NFT correspondant.
     */
    function claim(uint256 _tokenId) external nonReentrant {
        // 1. INTERACTION ERC-721 : Vérification du propriétaire ||  On demande au contrat NFT : "Qui possède l'ID X ?"
        address nftOwner = membershipNft.ownerOf(_tokenId);
        require(msg.sender == nftOwner, "Tu ne possedes pas ce NFT !");

        VestingInfo storage schedule = vestingSchedules[_tokenId];
        require(schedule.totalAllocation > 0, "Aucun vesting pour ce NFT");

        // 2. Calcul mathématique (similaire à ton ancien contrat)
        uint256 vested = _calculateVestedAmount(schedule);
        uint256 claimable = vested - schedule.releasedAmount;
        
        require(claimable > 0, "Rien a reclamer pour l'instant");

        // 3. Mise à jour de l'état
        schedule.releasedAmount += claimable;

        // 4. INTERACTION ERC-20 : Envoi des récompenses
        require(rewardToken.transfer(msg.sender, claimable), "Transfer failed");

        emit TokensClaimed(_tokenId, msg.sender, claimable);
    }

    // Fonction de lecture pour le Frontend ou les tests
    function getClaimableAmount(uint256 _tokenId) external view returns (uint256) {
        VestingInfo memory schedule = vestingSchedules[_tokenId];
        if (schedule.totalAllocation == 0) return 0;
        return _calculateVestedAmount(schedule) - schedule.releasedAmount;
    }

    // Calcul interne (Linéaire)
    function _calculateVestedAmount(VestingInfo memory schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.startTime) return 0;
        if (block.timestamp >= schedule.startTime + schedule.duration) return schedule.totalAllocation;

        uint256 timeElapsed = block.timestamp - schedule.startTime;
        return (schedule.totalAllocation * timeElapsed) / schedule.duration;
    }
}