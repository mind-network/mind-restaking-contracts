// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IXERC20} from "../tokens/IXERC20.sol";
import {IStrategy} from "./IStrategy.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title A general re-staking strategy for MIND remote staking
 * @author Zy
 */
contract Strategy is IStrategy, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using Math for uint256;

    IERC20 public assetToken;
    IXERC20 public shareToken;
    uint8 internal decimalsOffset;

    uint256 public depositAmountMax;
    uint256 public redeemAmountMax;

    uint256 public lockPeriod;
    mapping(address => uint256) public pendingRedeemRequest;
    mapping(address => uint256) public claimableRedeemRequest;
    mapping(address => uint256) public pendingRedeemRequestDeadline;

    function initialize(
        address _owner,
        IERC20 _assetToken,
        IXERC20 _shareToken,
        uint8 _decimalsOffset
    ) public initializer {
        __Ownable_init(_owner);
        __Pausable_init();
        __ReentrancyGuard_init();

        assetToken = _assetToken;
        shareToken = _shareToken;
        decimalsOffset = _decimalsOffset;
        depositAmountMax = type(uint256).max;
        redeemAmountMax = type(uint256).max;
    }

    function setup(uint256 _lockPeriod, uint256 _depositAmountMax, uint256 _redeemAmountMax) external onlyOwner {
        lockPeriod = _lockPeriod;
        depositAmountMax = _depositAmountMax;
        redeemAmountMax = _redeemAmountMax;
    }

    /**
     * @dev TODO Placeholder for remote staking migration
     * @notice Restake & Delegate all existing balance of assetToken into MIND Remote Stake Manager
     */
    function restakeAllBalance() external onlyOwner {}

    /**
     * @notice In case of any airdrop for asset token holders, owner can withdraw and redistribute.
     */
    function withdrawAirdropToken(IERC20 token) external onlyOwner {
        if (token == assetToken || token == shareToken) {
            revert OwnerCannotWithdrawAssetToken();
        }
        SafeERC20.safeTransfer(token, _msgSender(), token.balanceOf(address(this)));
    }

    /**
     * @notice Deposit asset token into the strategy.
     */
    function deposit(uint256 assetAmount) external whenNotPaused nonReentrant {
        if (assetAmount > depositAmountMax) {
            revert ExceededMax();
        }
        _depositFor(_msgSender(), assetAmount, _msgSender());
    }

    /**
     * @dev Allows for deposit on behalf of receiver. Asset token is stored in this contract before remote staking is ready.
     */
    function _depositFor(address user, uint256 assetAmount, address receiver) private {
        if (assetAmount == 0) {
            revert ZeroValueCheck();
        }
        uint256 shareAmount = _convertToShares(assetAmount, Math.Rounding.Floor);
        SafeERC20.safeTransferFrom(assetToken, user, address(this), assetAmount);
        shareToken.mint(receiver, shareAmount);
        emit Deposit(user, receiver, assetAmount, shareAmount);
    }

    /**
     * @notice When there is no locking period, users can withdraw directly.
     */
    function quickWithdraw(uint256 assetAmount) external whenNotPaused nonReentrant {
        if (lockPeriod != 0) {
            revert QuickWithdrawalDisabled();
        }
        uint256 shareAmount = _convertToShares(assetAmount, Math.Rounding.Ceil);
        if (shareAmount == 0) {
            revert ZeroValueCheck();
        }
        shareToken.burn(_msgSender(), shareAmount);
        SafeERC20.safeTransfer(assetToken, _msgSender(), assetAmount);
    }

    /**
     * @notice Submit a request for withdrawal when there is a locking period.
     */
    function requestWithdraw(uint256 assetAmount) external {
        uint256 shareAmount = _convertToShares(assetAmount, Math.Rounding.Ceil);
        requestRedeem(shareAmount);
    }

    /**
     * @notice Submit a request for redemption when there is a locking period.
     */
    function requestRedeem(uint256 shareAmount) public whenNotPaused nonReentrant {
        if (shareAmount > redeemAmountMax) {
            revert ExceededMax();
        }
        _requestRedeemFor(_msgSender(), shareAmount, _msgSender());
    }

    /**
     * @dev Allows for request for redemption on behalf of receiver.
     */
    function _requestRedeemFor(address user, uint256 shareAmount, address receiver) private {
        if (shareAmount == 0) {
            revert ZeroValueCheck();
        }
        SafeERC20.safeTransferFrom(shareToken, user, address(this), shareAmount);
        _updateRedeemLockPeriod(receiver, shareAmount);
        emit RedeemRequest(user, receiver, shareAmount);
    }

    /**
     * @notice Completes redemption for receiver when locking period is over.
     */
    function redeemFor(address receiver) external whenNotPaused nonReentrant {
        _updateRedeemLockPeriod(receiver, 0);
        uint256 shareAmount = claimableRedeemRequest[receiver];
        if (shareAmount == 0) {
            revert ZeroValueCheck();
        }
        claimableRedeemRequest[receiver] = 0;
        uint256 assetAmount = _convertToAssets(shareAmount, Math.Rounding.Floor);
        shareToken.burn(address(this), shareAmount);
        SafeERC20.safeTransfer(assetToken, receiver, assetAmount);
        emit Redeem(receiver, shareAmount, assetAmount);
    }

    /**
     * @notice Get latest information for a user wallet.
     */
    function getInfo(address user) external returns (uint256, uint256, uint256, uint256, uint256) {
        _updateRedeemLockPeriod(user, 0);
        uint256 shareAmount = shareToken.balanceOf(user);
        uint256 assetAmount = _convertToAssets(shareAmount, Math.Rounding.Floor);
        uint256 pendingAssetAmount = _convertToAssets(pendingRedeemRequest[user], Math.Rounding.Floor);
        uint256 timeTowithdraw = Math.max(pendingRedeemRequestDeadline[user], block.number) - block.number;
        uint256 claimableAssetAmount = _convertToAssets(claimableRedeemRequest[user], Math.Rounding.Floor);
        return (shareAmount, assetAmount, pendingAssetAmount, timeTowithdraw, claimableAssetAmount);
    }

    /**
     * @dev Lock period is currently calculated as weighted average. Lock period will be handled by remote staking contract when remote staking is ready.
     */
    function _updateRedeemLockPeriod(address user, uint256 newRequestAmount) private {
        if (pendingRedeemRequest[user] == 0 && newRequestAmount == 0) {
            return;
        } else if (pendingRedeemRequest[user] == 0) {
            pendingRedeemRequest[user] = newRequestAmount;
            pendingRedeemRequestDeadline[user] = block.number + lockPeriod;
        } else if (pendingRedeemRequestDeadline[user] <= block.number) {
            claimableRedeemRequest[user] += pendingRedeemRequest[user];
            pendingRedeemRequest[user] = newRequestAmount;
            pendingRedeemRequestDeadline[user] = block.number + lockPeriod;
        } else {
            uint256 newLockPeriod = (newRequestAmount *
                lockPeriod +
                pendingRedeemRequest[user] *
                (pendingRedeemRequestDeadline[user] - block.number)).ceilDiv(
                    newRequestAmount + pendingRedeemRequest[user]
                );
            pendingRedeemRequest[user] += newRequestAmount;
            pendingRedeemRequestDeadline[user] = block.number + newLockPeriod;
        }
    }

    /**
     * @dev Same as @openzeppelin ERC4626 implementation
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256) {
        return assets.mulDiv(shareToken.totalSupply() + 10 ** decimalsOffset, totalAssets() + 1, rounding);
    }

    /**
     * @dev Same as @openzeppelin ERC4626 implementation
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, shareToken.totalSupply() + 10 ** decimalsOffset, rounding);
    }

    function totalAssets() public view virtual returns (uint256) {
        return assetToken.balanceOf(address(this));
    }
}
