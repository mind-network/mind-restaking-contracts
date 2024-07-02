// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IStrategy} from "./IStrategy.sol";

interface IFixedStrategy is IStrategy {
    error NotReachMinBalance();

    error NoWithdrawDuringCampaign();

    error DepositOnlyDuringCampaign();

    event SetCampaignParam(uint256 campaignUntil, uint256 minBalance);

    function setCampaignParam(uint256 _campaignUntil, uint256 _minBalance) external;

    function getCampaignParam() external view returns (uint256 _campaignUntil, uint256 _minBalance);
}
