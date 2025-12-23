// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // ✅ Import ReentrancyGuard

contract SafeBank is Ownable, ReentrancyGuard {
    mapping(address => uint256) public balances;
    address public loggerAddress;
    uint256 public withdrawalFee = 1;

    constructor() Ownable(msg.sender) {}

    function deposit() external payable {
        // ✅ Protection Overflow/Underflow : On a retiré "unchecked".
        // Solidity 0.8+ gère cela nativement.
        balances[msg.sender] += msg.value;
    }

    // ✅ ReentrancyGuard : Ajout du modificateur nonReentrant
    function withdraw() external nonReentrant {
        // 1. CHECKS (Vérifications)
        uint256 userBalance = balances[msg.sender];
        require(userBalance > 0, "Solde insuffisant");

        // Calcule le montant après les frais
        uint256 amountToWithdraw = userBalance - (userBalance * withdrawalFee / 100);

        // 2. EFFECTS (Effets) : On met à jour l'état AVANT d'envoyer l'argent
        balances[msg.sender] = 0;

        // 3. INTERACTIONS (Interactions) : On envoie l'Ether à la fin
        (bool sent,) = msg.sender.call{value: amountToWithdraw}("");
        require(sent, "Echec de l'envoi d'Ether");
    }

    function setWithdrawalFee(uint256 _newFee) external {
        // ✅ Authentification : On remplace tx.origin par msg.sender (via onlyOwner ou check direct)
        require(msg.sender == owner(), "Seul le proprietaire peut changer les frais");

        // ✅ Validation des entrées
        require(_newFee <= 5, "Les frais ne peuvent pas depasser 5%");
        withdrawalFee = _newFee;
    }

    function setLogger(address _newLogger) external onlyOwner {
        // ✅ Validation des entrées : On vérifie que l'adresse n'est pas nulle
        require(_newLogger != address(0), "Logger address cannot be zero");
        loggerAddress = _newLogger;

        // ✅ Appels externes vérifiés : On vérifie le retour de .call
        (bool success,) = loggerAddress.call(abi.encodeWithSignature("log(string)", "Adresse du logger mise a jour"));
        require(success, "Log failed");
    }
}
