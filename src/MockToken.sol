// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    // On crée un token "My Test Token" (MTT) et on se donne 1 million d'unités
    constructor() ERC20("My Test Token", "MTT") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}
