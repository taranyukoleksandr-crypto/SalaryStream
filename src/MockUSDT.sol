// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {
        // Одразу при деплої друкуємо 10,000 токенів власнику
        _mint(msg.sender, 10000 * 10 ** decimals()); 
    }
}
