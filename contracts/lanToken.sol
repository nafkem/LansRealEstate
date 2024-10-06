//// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Token is ERC20 {
    constructor() ERC20("LansERC20", "LAN"){
        _mint(msg.sender, 1 * 10 ** 18);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
