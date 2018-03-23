pragma solidity ^0.4.19;

import "./ErrorCodes.sol";

contract Superblocks is ErrorCodes {

    uint constant SUPERBLOCK_PERIOD = 0;

    enum Status { Unitialized, New, InBattle, SemiApproved, Approved, Invalid }

    struct SuperblockInfo {
        bytes32 blocksMerkleRoot;
        uint accumulatedWork;
        uint timestamp;
        bytes32 lastHash;
        bytes32 parentHash;
        address submitter;
        uint timeout;
        Status status;

        uint numChallenges;
        uint currChallenge;

        // bytes32[] hashes;
        // mapping (bytes32 => bytes)
    }

    // Mapping superblock id => superblock data
    mapping (bytes32 => SuperblockInfo) superblocks;

    struct ChallengeInfo {
        address challenger;
        address submitter;
        bytes32 superblockId;
        uint round;
    }

    mapping (bytes32 => ChallengeInfo) challenges;

    uint numChallenges;

    bytes32 bestSuperblock;
    uint accumulatedWork;

    //TODO: Add 'indexed' to parameters
    event NewSuperblock(bytes32 superblockId);
    event ApprovedSuperblock(bytes32 superblockId);

    event ChallengeSuperblock(bytes32 superblockId, address challenger, bytes32 challengeId);
    event ErrorSuperblock(bytes32 superblockId, uint err);

    function Superblock() public {
    }

    function initialize(bytes32 _blocksMerkleRoot, uint _accumulatedWork, uint _timestamp, bytes32 _lastHash, bytes32 _parentHash) public returns (uint) {
        bytes32 superblockId = keccak256(_blocksMerkleRoot, _accumulatedWork, _timestamp, _lastHash, _parentHash);
        SuperblockInfo storage sbi = superblocks[superblockId];
        require(sbi.status == Status.Unitialized);
        sbi.blocksMerkleRoot = _blocksMerkleRoot;
        sbi.accumulatedWork = _accumulatedWork;
        sbi.timestamp = _timestamp;
        sbi.lastHash = _lastHash;
        sbi.parentHash = _parentHash;
        sbi.submitter = msg.sender;
        sbi.timeout = now;
        sbi.status = Status.Approved;
        sbi.currChallenge = 0;
        sbi.numChallenges = 0;

        NewSuperblock(superblockId);

        bestSuperblock = superblockId;
        accumulatedWork = _accumulatedWork;

        ApprovedSuperblock(superblockId);

        return ERR_SUPERBLOCK_OK;
    }

    function proposeSuperblock(bytes32 _blocksMerkleRoot, uint _accumulatedWork, uint _timestamp, bytes32 _lastHash, bytes32 _parentHash) public returns (uint) {
        bytes32 superblockId = keccak256(_blocksMerkleRoot, _accumulatedWork, _timestamp, _lastHash, _parentHash);
        SuperblockInfo storage sbi = superblocks[superblockId];

        // Make sure it was not submitted
        if (sbi.status != Status.Unitialized) {
            ErrorSuperblock(superblockId, ERR_SUPERBLOCK_EXIST);
            return ERR_SUPERBLOCK_EXIST;
        }

        sbi.blocksMerkleRoot = _blocksMerkleRoot;
        sbi.accumulatedWork = _accumulatedWork;
        sbi.timestamp = _timestamp;
        sbi.lastHash = _lastHash;
        sbi.parentHash = _parentHash;
        sbi.submitter = msg.sender;
        sbi.timeout = now;
        sbi.status = Status.New;
        sbi.currChallenge = 0;
        sbi.numChallenges = 0;

        NewSuperblock(superblockId);

        return ERR_SUPERBLOCK_OK;
    }

    function confirmSuperblock(bytes32 superblockId) public returns (uint) {
        //TODO: verify authorised msg.sender
        SuperblockInfo storage sbi = superblocks[superblockId];
        if (sbi.status != Status.New) {
            ErrorSuperblock(superblockId, ERR_SUPERBLOCK_BAD_STATUS);
            return ERR_SUPERBLOCK_BAD_STATUS;
        }
        if (now - sbi.timeout < SUPERBLOCK_PERIOD) {
            ErrorSuperblock(superblockId, ERR_SUPERBLOCK_TIMEOUT);
            return ERR_SUPERBLOCK_TIMEOUT;
        }
        sbi.status = Status.Approved;
        if (sbi.accumulatedWork > accumulatedWork) {
            bestSuperblock = superblockId;
            accumulatedWork = sbi.accumulatedWork;
        }
        ApprovedSuperblock(superblockId);
        return ERR_SUPERBLOCK_OK;
    }

    function challengeSuperblock(bytes32 superblockId) public returns (uint) {
        SuperblockInfo storage sbi = superblocks[superblockId];

        if (sbi.status != Status.New && sbi.status != Status.InBattle) {
            ErrorSuperblock(superblockId, ERR_SUPERBLOCK_BAD_STATUS);
            return ERR_SUPERBLOCK_BAD_STATUS;
        }

        sbi.status = Status.InBattle;

        bytes32 challengeId = bytes32(++numChallenges);
        sbi.numChallenges++;

        ChallengeInfo storage ci = challenges[challengeId];

        ci.challenger = msg.sender;
        ci.submitter = sbi.submitter;
        ci.superblockId = superblockId;

        ChallengeSuperblock(superblockId, msg.sender, challengeId);

        return ERR_SUPERBLOCK_OK;
    }

    function sendHashes(bytes32 challengeId, bytes32[] hashes) public {
        ChallengeInfo storage ci = challenges[challengeId];
        SuperblockInfo storage sbi = superblocks[ci.superblockId];
        require(sbi.submitter == msg.sender);
        if (VerifyMerkleRoot(sbi, hashes)) {
            sbi.status = Status.Invalid;
            // Send deposit to challenger
            ErrorSuperblock(ci.superblockId, ERR_SUPERBLOCK_INVALID_MERKLE);
        }
    }

    function response(bytes32 challengeId, uint what, bytes data) public {

    }

    function query(bytes32 challengeId, uint what) public {

    }

    function VerifyMerkleRoot(SuperblockInfo storage sbi, bytes32[] hashes) internal returns (bool) {
        return false;
    }

    // Getters

    function getBestSuperblock() public view returns (bytes32) {
        return bestSuperblock;
    }

    function getSuperblock(bytes32 superblockId) public view returns (bytes32, uint, uint, bytes32, bytes32, address, uint, Status) {
        SuperblockInfo storage sbi = superblocks[superblockId];
        return (
            sbi.blocksMerkleRoot,
            sbi.accumulatedWork,
            sbi.timestamp,
            sbi.lastHash,
            sbi.parentHash,
            sbi.submitter,
            sbi.timeout,
            sbi.status
        );
    }

}
