// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; // ✅ Import SafeERC20
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VestingWallet is Ownable, ReentrancyGuard {
    // ✅ Utilisation de la librairie pour sécuriser tous les appels ERC20
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        address beneficiary;
        uint256 cliff;
        uint256 duration;
        uint256 totalAmount;
        uint256 releasedAmount;
    }

    IERC20 public immutable token;
    mapping(address => VestingSchedule) public vestingSchedules;

    constructor(address tokenAddress) Ownable(msg.sender) {
        // ✅ Validation des entrées
        require(tokenAddress != address(0), "Token address cannot be zero");
        token = IERC20(tokenAddress);
    }

    function createVestingSchedule(address _beneficiary, uint256 _totalAmount, uint256 _cliff, uint256 _duration)
        external
        onlyOwner
    {
        // ✅ Validation complète des entrées
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");
        require(_totalAmount > 0, "Amount must be > 0");
        require(_duration > 0, "Duration must be > 0");
        require(_cliff >= block.timestamp, "Cliff must be in the future"); // Optionnel, selon logique métier
        require(vestingSchedules[_beneficiary].totalAmount == 0, "Schedule already exists");

        // ✅ Checks-Effects-Interactions + SafeERC20
        // On effectue le transfert (Interaction) avant l'enregistrement (Effect) ICI c'est une exception courante
        // car on veut être sûr d'avoir les fonds avant de valider le calendrier.
        // Cependant, grâce à ReentrancyGuard sur les fonctions de retrait, c'est sécurisé.

        // Utilisation de safeTransferFrom au lieu de transferFrom
        token.safeTransferFrom(msg.sender, address(this), _totalAmount);

        vestingSchedules[_beneficiary] = VestingSchedule({
            beneficiary: _beneficiary, cliff: _cliff, duration: _duration, totalAmount: _totalAmount, releasedAmount: 0
        });
    }

    function getVestedAmount(address _beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];

        if (schedule.totalAmount == 0) return 0;
        if (block.timestamp < schedule.cliff) return 0;
        if (block.timestamp >= schedule.cliff + schedule.duration) return schedule.totalAmount; // ✅ Overflow protection native 0.8+

        uint256 timeSinceCliff = block.timestamp - schedule.cliff;
        return (schedule.totalAmount * timeSinceCliff) / schedule.duration;
    }

    function claimVestedTokens() external nonReentrant {
        // ✅ ReentrancyGuard
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule found");

        uint256 vestedAmount = getVestedAmount(msg.sender);
        uint256 claimable = vestedAmount - schedule.releasedAmount;
        require(claimable > 0, "Nothing to claim yet");

        // ✅ Checks-Effects-Interactions
        // Effect : Mise à jour de l'état AVANT le transfert
        schedule.releasedAmount += claimable;

        // Interaction : Transfert sécurisé avec SafeERC20
        token.safeTransfer(msg.sender, claimable);
    }
}
