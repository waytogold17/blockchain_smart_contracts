// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VestingWallet is Ownable, ReentrancyGuard {

    struct VestingSchedule {
        address beneficiary;
        uint256 start;          // Ajout : Date de début du vesting (timestamp)
        uint256 cliff;          // Date (timestamp) avant laquelle rien n'est libéré
        uint256 duration;       // Durée totale du vesting en secondes
        uint256 totalAmount;    // Montant total de jetons à vest
        uint256 releasedAmount; // Montant déjà retiré par le bénéficiaire
        bool initialized;       // Pour vérifier si le calendrier existe
    }

    IERC20 public immutable token;
    
    // Mapping d'une adresse vers son calendrier de vesting
    mapping(address => VestingSchedule) public vestingSchedules;

    // Événements pour la transparence
    event ScheduleCreated(address indexed beneficiary, uint256 amount);
    event TokensClaimed(address indexed beneficiary, uint256 amount);

    constructor(address tokenAddress) Ownable(msg.sender) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        token = IERC20(tokenAddress);
    }

    /**
     * @dev Crée un nouveau calendrier de vesting.
     * @param _beneficiary L'adresse de l'employé.
     * @param _totalAmount Le montant total de jetons à bloquer.
     * @param _cliffDuration La durée du cliff en secondes (ex: 6 mois = 15778463).
     * @param _duration La durée totale du vesting en secondes (ex: 2 ans = 63113852).
     */
    function createVestingSchedule(
        address _beneficiary, 
        uint256 _totalAmount, 
        uint256 _cliffDuration, 
        uint256 _duration
    ) public onlyOwner {
        require(_beneficiary != address(0), "Beneficiary cannot be zero");
        require(_totalAmount > 0, "Amount must be > 0");
        require(_duration > 0, "Duration must be > 0");
        require(_cliffDuration <= _duration, "Cliff must be < duration");
        require(!vestingSchedules[_beneficiary].initialized, "Schedule already exists");

        // 1. Définir les temps
        uint256 startTime = block.timestamp;
        uint256 cliffTime = startTime + _cliffDuration;

        // 2. Créer la structure
        vestingSchedules[_beneficiary] = VestingSchedule({
            beneficiary: _beneficiary,
            start: startTime,
            cliff: cliffTime,
            duration: _duration,
            totalAmount: _totalAmount,
            releasedAmount: 0,
            initialized: true
        });

        // 3. IMPORTANT : Transférer les jetons du Owner vers ce Contrat
        // Le Owner doit avoir fait un "approve" au préalable !
        bool success = token.transferFrom(msg.sender, address(this), _totalAmount);
        require(success, "Token transfer failed");

        emit ScheduleCreated(_beneficiary, _totalAmount);
    }

    /**
     * @dev Permet au bénéficiaire de réclamer ses jetons disponibles.
     */
    function claimVestedTokens() public nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.initialized, "No schedule for caller");
        require(block.timestamp >= schedule.cliff, "Cliff not reached");

        // 1. Calculer combien de jetons sont "vested" (acquis) au total à ce jour
        uint256 vestedAmount = _calculateVestedAmount(msg.sender);
        
        // 2. Calculer combien sont réclamables (Acquis - Déjà retirés)
        uint256 claimableAmount = vestedAmount - schedule.releasedAmount;
        require(claimableAmount > 0, "Nothing to claim");

        // 3. Mettre à jour l'état AVANT le transfert (sécurité)
        schedule.releasedAmount += claimableAmount;

        // 4. Transférer les jetons
        bool success = token.transfer(msg.sender, claimableAmount);
        require(success, "Transfer failed");

        emit TokensClaimed(msg.sender, claimableAmount);
    }

    /**
     * @dev Calcule le montant total acquis (vested) à l'instant T.
     */
    function getVestedAmount(address _beneficiary) public view returns (uint256) {
        return _calculateVestedAmount(_beneficiary);
    }

    // Fonction interne pour éviter la duplication de code
    function _calculateVestedAmount(address _beneficiary) internal view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];

        if (!schedule.initialized) return 0;

        // Si on est avant le Cliff, rien n'est acquis
        if (block.timestamp < schedule.cliff) {
            return 0;
        }

        // Si la durée est écoulée, tout est acquis
        if (block.timestamp >= schedule.start + schedule.duration) {
            return schedule.totalAmount;
        }

        // Sinon, calcul linéaire : (Total * Temps écoulé) / Durée Totale
        uint256 timeElapsed = block.timestamp - schedule.start;
        return (schedule.totalAmount * timeElapsed) / schedule.duration;
    }
}