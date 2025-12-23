// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VestingWallet.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 1. Création d'un Faux Jeton pour le test (Mock)
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MCK") {
        _mint(msg.sender, 1000000 * 10**18); // On se donne 1 million de tokens au début
    }
}

contract VestingWalletTest is Test {
    VestingWallet public vestingWallet;
    MockERC20 public token;

    address public owner;
    address public beneficiary;

    function setUp() public {
        // Configuration initiale
        owner = address(this);           // Le test est le "patron"
        beneficiary = address(0x123);    // Un employé fictif
        
        // Déploiement du faux jeton et du wallet
        token = new MockERC20();
        vestingWallet = new VestingWallet(address(token));

        // IMPORTANT: L'owner doit approuver le vesting wallet pour qu'il puisse prendre les sous
        token.approve(address(vestingWallet), type(uint256).max);
    }

    function test_FullVestingScenario() public {
        uint256 totalAmount = 1000 * 10**18; // 1000 tokens
        uint256 duration = 1000 seconds;     // Durée de 1000 secondes pour simplifier les maths
        uint256 cliff = block.timestamp;     // Le cliff commence "maintenant"

        // 1. Création du calendrier
        vestingWallet.createVestingSchedule(beneficiary, totalAmount, cliff, duration);
        
        // Vérification : Le contrat a bien pris les tokens
        assertEq(token.balanceOf(address(vestingWallet)), totalAmount);

        // 2. Test avant le temps écoulé (devrait être 0 ou très peu)
        // On simule l'employé qui essaie de retirer tout de suite
        vm.prank(beneficiary); // Le prochain appel vient du beneficiary
        vm.expectRevert("Nothing to claim yet"); // On s'attend à ce que ça échoue
        vestingWallet.claimVestedTokens();

        // 3. VOYAGE DANS LE TEMPS : On avance de 50% de la durée (500 secondes)
        vm.warp(cliff + 500); 

        // Vérification du montant débloqué (devrait être 500 tokens)
        uint256 vested = vestingWallet.getVestedAmount(beneficiary);
        assertEq(vested, 500 * 10**18);

        // 4. Retrait des fonds
        vm.prank(beneficiary); // L'employé appelle
        vestingWallet.claimVestedTokens();

        // Vérification finale : L'employé a bien reçu ses 500 tokens
        assertEq(token.balanceOf(beneficiary), 500 * 10**18);
    }
}