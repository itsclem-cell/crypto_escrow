// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IEscrow } from "../interfaces/IEscrow.sol";
import { AssetLib } from "../utils/AssetLib.sol";

contract Escrow is IEscrow, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    error InvalidAddress();
    error InvalidAmount();
    error InvalidDeadlines();
    error InvalidStatus();
    error Unauthorized();
    error IncorrectAssetType();
    error IncorrectDepositAmount();
    error FeeTooHigh();
    error DisputeAlreadyRaised();
    error TimeoutNotReached();
    error EscrowInDispute();

    uint256 public constant MAX_FEE_BPS = 1_000; // 10%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    address public immutable payer;
    address public immutable payee;
    address public immutable arbiter;
    address public immutable asset;
    address public immutable feeRecipient;

    uint256 public immutable amount;
    uint256 public immutable fee;
    uint256 public immutable releaseAfter;
    uint256 public immutable refundAfter;
    bytes32 public immutable termsHash;

    Status public status;

    bool public payerApprovedRelease;
    bool public payeeApprovedRelease;
    bool public payerApprovedRefund;
    bool public payeeApprovedRefund;

    modifier onlyParty() {
        if (msg.sender != payer && msg.sender != payee) revert Unauthorized();
        _;
    }

    modifier onlyArbiter() {
        if (msg.sender != arbiter) revert Unauthorized();
        _;
    }

    modifier inStatus(Status expected) {
        if (status != expected) revert InvalidStatus();
        _;
    }

    constructor(
        address payer_,
        address payee_,
        address arbiter_,
        address asset_,
        address feeRecipient_,
        uint256 amount_,
        uint256 feeBps_,
        uint256 releaseAfter_,
        uint256 refundAfter_,
        bytes32 termsHash_
    ) {
        if (payer_ == address(0) || payee_ == address(0) || arbiter_ == address(0) || feeRecipient_ == address(0)) {
            revert InvalidAddress();
        }
        if (payer_ == payee_) revert InvalidAddress();
        if (amount_ == 0) revert InvalidAmount();
        if (releaseAfter_ <= block.timestamp || refundAfter_ <= releaseAfter_) revert InvalidDeadlines();
        if (feeBps_ > MAX_FEE_BPS) revert FeeTooHigh();

        payer = payer_;
        payee = payee_;
        arbiter = arbiter_;
        asset = asset_;
        feeRecipient = feeRecipient_;
        amount = amount_;
        fee = (amount_ * feeBps_) / BPS_DENOMINATOR;
        releaseAfter = releaseAfter_;
        refundAfter = refundAfter_;
        termsHash = termsHash_;
        status = Status.AwaitingDeposit;
    }

    receive() external payable {
        if (!AssetLib.isNative(asset)) revert IncorrectAssetType();
    }

    function depositNative() external payable nonReentrant whenNotPaused inStatus(Status.AwaitingDeposit) {
        if (msg.sender != payer) revert Unauthorized();
        if (!AssetLib.isNative(asset)) revert IncorrectAssetType();
        if (msg.value != amount) revert IncorrectDepositAmount();

        status = Status.Funded;
        emit Deposited(msg.sender, msg.value);
    }

    function depositToken() external nonReentrant whenNotPaused inStatus(Status.AwaitingDeposit) {
        if (msg.sender != payer) revert Unauthorized();
        if (AssetLib.isNative(asset)) revert IncorrectAssetType();

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        status = Status.Funded;
        emit Deposited(msg.sender, amount);
    }

    function approveRelease() external whenNotPaused inStatus(Status.Funded) onlyParty {
        if (msg.sender == payer) {
            payerApprovedRelease = true;
        } else {
            payeeApprovedRelease = true;
        }

        emit ReleaseApproved(msg.sender);

        if (payerApprovedRelease && payeeApprovedRelease) {
            _release();
        }
    }

    function approveRefund() external whenNotPaused inStatus(Status.Funded) onlyParty {
        if (msg.sender == payer) {
            payerApprovedRefund = true;
        } else {
            payeeApprovedRefund = true;
        }

        emit RefundApproved(msg.sender);

        if (payerApprovedRefund && payeeApprovedRefund) {
            _refund();
        }
    }

    function raiseDispute(string calldata reason) external whenNotPaused inStatus(Status.Funded) onlyParty {
        if (status == Status.Disputed) revert DisputeAlreadyRaised();
        status = Status.Disputed;
        emit DisputeRaised(msg.sender, reason);
    }

    function clearDispute() external whenNotPaused inStatus(Status.Disputed) onlyArbiter {
        status = Status.Funded;
        emit DisputeCleared(msg.sender);
    }

    function arbiterRelease() external whenNotPaused inStatus(Status.Disputed) onlyArbiter {
        _release();
    }

    function arbiterRefund() external whenNotPaused inStatus(Status.Disputed) onlyArbiter {
        _refund();
    }

    function releaseByTimeout() external whenNotPaused {
        if (status != Status.Funded) revert InvalidStatus();
        if (block.timestamp < releaseAfter) revert TimeoutNotReached();
        _release();
    }

    function refundByTimeout() external whenNotPaused {
        if (status != Status.Funded) revert InvalidStatus();
        if (block.timestamp < refundAfter) revert TimeoutNotReached();
        _refund();
    }

    function cancelBeforeFunding() external whenNotPaused inStatus(Status.AwaitingDeposit) {
        if (msg.sender != payer) revert Unauthorized();
        status = Status.Cancelled;
        emit EscrowCancelled(msg.sender);
    }

    function getEscrowView() external view returns (EscrowView memory viewData) {
        viewData = EscrowView({
            payer: payer,
            payee: payee,
            arbiter: arbiter,
            asset: asset,
            feeRecipient: feeRecipient,
            amount: amount,
            fee: fee,
            releaseAfter: releaseAfter,
            refundAfter: refundAfter,
            termsHash: termsHash,
            status: status,
            payerApprovedRelease: payerApprovedRelease,
            payeeApprovedRelease: payeeApprovedRelease,
            payerApprovedRefund: payerApprovedRefund,
            payeeApprovedRefund: payeeApprovedRefund
        });
    }

    function pause() external onlyArbiter {
        _pause();
    }

    function unpause() external onlyArbiter {
        _unpause();
    }

    function _release() internal nonReentrant {
        status = Status.Released;

        uint256 netAmount = amount - fee;
        AssetLib.transferOut(asset, payee, netAmount);
        AssetLib.transferOut(asset, feeRecipient, fee);

        emit Released(payee, netAmount, fee);
    }

    function _refund() internal nonReentrant {
        status = Status.Refunded;
        AssetLib.transferOut(asset, payer, amount);
        emit Refunded(payer, amount);
    }
}
