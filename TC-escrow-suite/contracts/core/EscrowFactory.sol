// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Escrow } from "./Escrow.sol";

contract EscrowFactory is Ownable2Step {
    error InvalidAddress();
    error FeeTooHigh();

    uint256 public constant MAX_DEFAULT_FEE_BPS = 1_000; // 10%

    address public treasury;
    address public defaultArbiter;
    uint256 public defaultFeeBps;

    address[] private _escrows;
    mapping(address => bool) public isEscrow;
    mapping(address => address[]) private _payerEscrows;
    mapping(address => address[]) private _payeeEscrows;

    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event DefaultArbiterUpdated(address indexed oldArbiter, address indexed newArbiter);
    event DefaultFeeBpsUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event EscrowCreated(
        address indexed escrow,
        address indexed payer,
        address indexed payee,
        address asset,
        uint256 amount,
        uint256 feeBps,
        uint256 releaseAfter,
        uint256 refundAfter,
        bytes32 termsHash
    );

    constructor(address initialOwner, address treasury_, address defaultArbiter_, uint256 defaultFeeBps_) Ownable(initialOwner) {
        if (initialOwner == address(0) || treasury_ == address(0) || defaultArbiter_ == address(0)) revert InvalidAddress();
        if (defaultFeeBps_ > MAX_DEFAULT_FEE_BPS) revert FeeTooHigh();

        treasury = treasury_;
        defaultArbiter = defaultArbiter_;
        defaultFeeBps = defaultFeeBps_;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert InvalidAddress();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    function setDefaultArbiter(address newArbiter) external onlyOwner {
        if (newArbiter == address(0)) revert InvalidAddress();
        emit DefaultArbiterUpdated(defaultArbiter, newArbiter);
        defaultArbiter = newArbiter;
    }

    function setDefaultFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_DEFAULT_FEE_BPS) revert FeeTooHigh();
        emit DefaultFeeBpsUpdated(defaultFeeBps, newFeeBps);
        defaultFeeBps = newFeeBps;
    }

    function createEscrow(
        address payer,
        address payee,
        address asset,
        uint256 amount,
        uint256 releaseAfter,
        uint256 refundAfter,
        bytes32 termsHash
    ) external returns (address escrowAddress) {
        escrowAddress = _createEscrow(
            payer,
            payee,
            defaultArbiter,
            asset,
            treasury,
            amount,
            defaultFeeBps,
            releaseAfter,
            refundAfter,
            termsHash
        );
    }

    function createEscrowCustom(
        address payer,
        address payee,
        address arbiter,
        address asset,
        address feeRecipient,
        uint256 amount,
        uint256 feeBps,
        uint256 releaseAfter,
        uint256 refundAfter,
        bytes32 termsHash
    ) external returns (address escrowAddress) {
        escrowAddress = _createEscrow(
            payer,
            payee,
            arbiter,
            asset,
            feeRecipient,
            amount,
            feeBps,
            releaseAfter,
            refundAfter,
            termsHash
        );
    }

    function totalEscrows() external view returns (uint256) {
        return _escrows.length;
    }

    function escrowAt(uint256 index) external view returns (address) {
        return _escrows[index];
    }

    function getPayerEscrows(address payer) external view returns (address[] memory) {
        return _payerEscrows[payer];
    }

    function getPayeeEscrows(address payee) external view returns (address[] memory) {
        return _payeeEscrows[payee];
    }

    function _createEscrow(
        address payer,
        address payee,
        address arbiter,
        address asset,
        address feeRecipient,
        uint256 amount,
        uint256 feeBps,
        uint256 releaseAfter,
        uint256 refundAfter,
        bytes32 termsHash
    ) internal returns (address escrowAddress) {
        Escrow escrow = new Escrow(
            payer,
            payee,
            arbiter,
            asset,
            feeRecipient,
            amount,
            feeBps,
            releaseAfter,
            refundAfter,
            termsHash
        );

        escrowAddress = address(escrow);
        isEscrow[escrowAddress] = true;
        _escrows.push(escrowAddress);
        _payerEscrows[payer].push(escrowAddress);
        _payeeEscrows[payee].push(escrowAddress);

        emit EscrowCreated(
            escrowAddress,
            payer,
            payee,
            asset,
            amount,
            feeBps,
            releaseAfter,
            refundAfter,
            termsHash
        );
    }
}
