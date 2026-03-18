// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IEscrow {
    enum Status {
        Uninitialized,
        AwaitingDeposit,
        Funded,
        Disputed,
        Released,
        Refunded,
        Cancelled
    }

    struct EscrowView {
        address payer;
        address payee;
        address arbiter;
        address asset;
        address feeRecipient;
        uint256 amount;
        uint256 fee;
        uint256 releaseAfter;
        uint256 refundAfter;
        bytes32 termsHash;
        Status status;
        bool payerApprovedRelease;
        bool payeeApprovedRelease;
        bool payerApprovedRefund;
        bool payeeApprovedRefund;
    }

    event Deposited(address indexed sender, uint256 amount);
    event ReleaseApproved(address indexed approver);
    event RefundApproved(address indexed approver);
    event DisputeRaised(address indexed actor, string reason);
    event DisputeCleared(address indexed actor);
    event Released(address indexed recipient, uint256 netAmount, uint256 feeAmount);
    event Refunded(address indexed recipient, uint256 amount);
    event EscrowCancelled(address indexed actor);

    function depositNative() external payable;
    function depositToken() external;
    function approveRelease() external;
    function approveRefund() external;
    function raiseDispute(string calldata reason) external;
    function clearDispute() external;
    function arbiterRelease() external;
    function arbiterRefund() external;
    function releaseByTimeout() external;
    function refundByTimeout() external;
    function cancelBeforeFunding() external;
    function getEscrowView() external view returns (EscrowView memory);
}
