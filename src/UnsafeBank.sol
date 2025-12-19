// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title UnsafeBank
 * @dev CETTE BANQUE EST VOLONTAIREMENT VULNÉRABLE. NE PAS UTILISER EN PRODUCTION.
 * Les utilisateurs peuvent déposer et retirer de l'Ether. Le propriétaire peut changer les frais.
 */
contract UnsafeBank is Ownable {
    mapping(address => uint256) public balances;
    address public loggerAddress;
    uint256 public withdrawalFee = 1; // Frais en pourcentage

    constructor() Ownable(msg.sender) {}

    // Dépose de l'Ether dans la banque
    function deposit() external payable {
        // On utilise unchecked pour "optimiser" le gaz... une mauvaise idée.
        unchecked {
            balances[msg.sender] += msg.value;
        }
    }

    // Retire l'intégralité du solde de l'utilisateur
    function withdraw() external {
        uint256 userBalance = balances[msg.sender];
        require(userBalance > 0, "Solde insuffisant");

        // Calcule le montant après les frais
        uint256 amountToWithdraw = userBalance - (userBalance * withdrawalFee / 100);

        // Envoie l'Ether AVANT de mettre à jour le solde (TRÈS DANGEREUX)
        (bool sent, ) = msg.sender.call{value: amountToWithdraw}("");
        require(sent, "Échec de l'envoi d'Ether");

        // Met à jour le solde après l'envoi
        balances[msg.sender] = 0;
    }

    // Fonction réservée au propriétaire pour changer les frais de retrait
    function setWithdrawalFee(uint256 _newFee) external {
        // Authentification dangereuse
        require(tx.origin == owner(), "Seul le propriétaire peut changer les frais");
        require(_newFee <= 5, "Les frais ne peuvent pas dépasser 5%");
        withdrawalFee = _newFee;
    }

    // Met à jour l'adresse d'un contrat de logging
    function setLogger(address _newLogger) external onlyOwner {
        loggerAddress = _newLogger;
        // Notifie le nouveau logger, mais sans vérifier si l'appel a réussi
        loggerAddress.call(abi.encodeWithSignature("log(string)", "Adresse du logger mise à jour"));
    }
}