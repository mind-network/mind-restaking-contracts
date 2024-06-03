// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, AccessControlUpgradeable {
    bytes32 public constant STRATEGY = keccak256("STRATEGY");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, string calldata name, string calldata symbol) initializer public {
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    /**
     * @notice Only STRATEGY is allowed to perform transfers, mints, and burns
     */
    function _update(address from, address to, uint256 value) internal override onlyRole(STRATEGY){
        super._update(from, to, value);
    }

    /**
     * @notice Gas optimization:
     *         Bypass allowance check, which is called within transferFrom and burnFrom.
     *         These two functions can only be invoked by STRATEGY.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal override {}
}
