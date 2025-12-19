// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MCK") {}

    // Fonction spéciale pour les tests : permet de créer de l'argent magique
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}