// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IFixedStrategy} from "./IFixedStrategy.sol";
import {IStrategy} from "./IStrategy.sol";
import {Strategy} from "./Strategy.sol";

contract FixedStrategy is IFixedStrategy, Strategy {
    uint256 private campaignUntil;
    uint256 private minBalance;

    /**
     * @notice Set parameters of the campaign
     * @param _campaignUntil the Unix timestamp (sec) for the end of the campaign
     * @param _minBalance the minimum balance requirement of the staker
     */
    function setCampaignParam(uint256 _campaignUntil, uint256 _minBalance) external onlyOwner {
        campaignUntil = _campaignUntil;
        minBalance = _minBalance;
    }

    function getCampaignParam() external view returns (uint256 _campaignUntil, uint256 _minBalance) {
        _campaignUntil = campaignUntil;
        _minBalance = minBalance;
    }

    function isCampaignActive() internal view returns (bool) {
        return block.timestamp < campaignUntil;
    }

    function deposit(uint256 assetAmount) public override(IStrategy, Strategy) {
        if (!isCampaignActive()) {
            revert();
        }
        if (assetAmount < minBalance) {
            uint256 prevShareBalance = shareToken.balanceOf(_msgSender());
            uint256 prevAssetBalance = prevShareBalance == 0 ? 0 : _convertToAssets(prevShareBalance, Math.Rounding.Floor);
            if (prevAssetBalance + assetAmount < minBalance) {
                revert NotReachMinBalance();
            }
        }
        Strategy.deposit(assetAmount);
    }

    function quickWithdraw(uint256 assetAmount) public override(IStrategy, Strategy) {
        if (isCampaignActive()) {
            revert NoWithdrawDuringCampaign();
        }
        Strategy.quickWithdraw(assetAmount);
    }

    function requestRedeem(uint256 shareAmount) public override(IStrategy, Strategy) {
        if (isCampaignActive()) {
            revert NoWithdrawDuringCampaign();
        }
        Strategy.requestRedeem(shareAmount);
    }
}
