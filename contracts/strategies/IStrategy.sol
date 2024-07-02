// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategy {
    error OwnerCannotWithdrawAssetToken();

    error ZeroValueCheck();

    error ExceededMax();

    error ExceededTotalAssetsCap();

    error QuickWithdrawalDisabled();

    event Deposit(address indexed user, address indexed receiver, uint256 assetAmount, uint256 shareAmount);

    event RedeemRequest(address indexed user, address indexed receiver, uint256 shareAmount);

    event Redeem(address indexed receiver, uint256 shareAmount, uint256 assetAmount);

    event QuickWithdraw(address indexed user, uint256 assetAmount, uint256 shareAmount);

    event Setup(uint256 lockPeriod, uint256 depositAmountMax, uint256 redeemAmountMax, uint256 totalAssetsCap);

    function deposit(uint256 assetAmount) external;

    function requestWithdraw(uint256 assetAmount) external;

    function requestRedeem(uint256 shareAmount) external;

    function redeemFor(address receiver) external;

    function quickWithdraw(uint256 assetAmount) external;

    function getInfo(address user) external returns (uint256, uint256, uint256, uint256, uint256);
}
