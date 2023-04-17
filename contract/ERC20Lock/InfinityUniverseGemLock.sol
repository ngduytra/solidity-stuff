// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CoinNameGem is ERC20, Pausable, Ownable {
    
    bool public isLock;

    constructor() ERC20("Coin Name Gem", "CNG") {
        _mint(msg.sender, 5 * 1e9 * 10 ** decimals());
        isLock = true;
    }

    function setLock(bool _isLock) external onlyOwner{
        isLock = _isLock;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _transfer(address from, address to, uint256 amount)
        internal 
        virtual 
        override
    {
        require(isLock == false || msg.sender == owner(), "Can not transfer token");
        super._transfer(from, to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}