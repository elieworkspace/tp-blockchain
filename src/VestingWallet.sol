// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VestingWallet is Ownable, ReentrancyGuard {
    
    // Structure pour stocker les infos d'un calendrier de vesting
    struct VestingSchedule {
        address beneficiary;    // L'employé
        uint256 cliff;          // Date de début du déblocage (timestamp)
        uint256 duration;       // Durée totale du vesting (en secondes)
        uint256 totalAmount;    // Montant total alloué
        uint256 releasedAmount; // Montant déjà retiré
    }

    // Le jeton que l'on va distribuer (immuable une fois défini)
    IERC20 public immutable token;

    // Mapping pour lier une adresse à son calendrier
    mapping(address => VestingSchedule) public vestingSchedules;

    // Constructeur : Initialise le propriétaire et l'adresse du jeton
    constructor(address tokenAddress) Ownable(msg.sender) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        token = IERC20(tokenAddress);
    }

    /**
     * @notice Crée un nouveau calendrier de vesting pour un bénéficiaire.
     * @dev L'owner doit avoir approuvé (approve) le contrat pour dépenser ses tokens avant d'appeler cette fonction !
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _cliff,
        uint256 _duration
    ) external onlyOwner {
        // 1. Vérifications de sécurité (Checks)
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");
        require(_totalAmount > 0, "Amount must be > 0");
        require(_duration > 0, "Duration must be > 0");
        // On s'assure qu'un vesting n'existe pas déjà pour cette personne
        require(vestingSchedules[_beneficiary].totalAmount == 0, "Schedule already exists");

        // 2. Transfert des fonds vers le contrat (Interactions)
        // Le contrat récupère les tokens du propriétaire pour les sécuriser
        bool success = token.transferFrom(msg.sender, address(this), _totalAmount);
        require(success, "Token transfer failed");

        // 3. Enregistrement du calendrier (Effects)
        vestingSchedules[_beneficiary] = VestingSchedule({
            beneficiary: _beneficiary,
            cliff: _cliff,
            duration: _duration,
            totalAmount: _totalAmount,
            releasedAmount: 0
        });
    }

    /**
     * @notice Calcule le montant total de jetons libérés (vested) à l'instant présent.
     * @dev La libération est linéaire après le cliff.
     */
    function getVestedAmount(address _beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];

        // S'il n'y a pas de calendrier, rien n'est dû
        if (schedule.totalAmount == 0) {
            return 0;
        }

        // Si on est avant la date de début (cliff), rien n'est débloqué
        if (block.timestamp < schedule.cliff) {
            return 0;
        }

        // Si la période de vesting est terminée, tout est débloqué
        if (block.timestamp >= schedule.cliff + schedule.duration) {
            return schedule.totalAmount;
        }

        // Sinon, calcul linéaire : (MontantTotal * TempsEcoulé) / DuréeTotale
        uint256 timeSinceCliff = block.timestamp - schedule.cliff;
        return (schedule.totalAmount * timeSinceCliff) / schedule.duration;
    }

    /**
     * @notice Permet au bénéficiaire de réclamer ses jetons débloqués.
     * @dev Utilise nonReentrant pour la sécurité.
     */
    function claimVestedTokens() external nonReentrant {
        // On récupère le calendrier de celui qui appelle la fonction (msg.sender)
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule found for sender");

        // Combien de tokens sont "mérités" au total à cet instant ?
        uint256 vestedAmount = getVestedAmount(msg.sender);
        
        // Combien peut-il retirer maintenant ? (Total mérité - Déjà retiré)
        uint256 claimable = vestedAmount - schedule.releasedAmount;
        require(claimable > 0, "Nothing to claim yet");

        // EFFECTS : On met à jour l'état AVANT le transfert (Protection anti-reentrance)
        schedule.releasedAmount += claimable;

        // INTERACTIONS : On envoie les jetons
        bool success = token.transfer(msg.sender, claimable);
        require(success, "Token transfer failed");
    }
}