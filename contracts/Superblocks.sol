pragma solidity ^0.4.19;

import "./ErrorCodes.sol";

contract Superblocks is ErrorCodes {

    uint constant SUPERBLOCK_PERIOD = 0;

    enum Status { Unitialized, New, InBattle, SemiApproved, Approved, Invalid }

    struct ChallengeInfo {

    }

    struct SuperblockInfo {
        bytes32 blocksMerkleRoot;
        uint accumulatedWork;
        uint timestamp;
        bytes32 lastHash;
        bytes32 parentHash;
        uint submitted;
        Status status;
        uint numChallenges;
        uint currChallenge;
        ChallengeInfo[] challenges;
    }


    // Mapping lastHash => superblock id
    //mapping (bytes32 => bytes32) indices;
    //uint indexLastSubmit;

    // Mapping superblock id => superblock data
    mapping (bytes32 => SuperblockInfo) superblocks;

    bytes32 bestSuperblock;
    uint accumulatedWork;

    //TODO: Add 'indexed' to parameters
    event NewSuperblock(bytes32 id);
    event ApprovedSuperblock(bytes32 id);
    event ChallengeSuperblock(bytes32 id, address challenger);
    event ErrorSuperblock(bytes32 id, uint err);

    function Superblock() public {
    }

    function initialize(bytes32 _blocksMerkleRoot, uint _accumulatedWork, uint _timestamp, bytes32 _lastHash, bytes32 _parentHash) public returns (uint) {
        //require(indexLastSubmit == 0);
        bytes32 id = keccak256(_blocksMerkleRoot, _accumulatedWork, _timestamp, _lastHash, _parentHash);
        SuperblockInfo storage sbi = superblocks[id];
        require(sbi.status == Status.Unitialized);
        //indices[indexLastSubmit] = id;
        sbi.blocksMerkleRoot = _blocksMerkleRoot;
        sbi.accumulatedWork = _accumulatedWork;
        sbi.timestamp = _timestamp;
        sbi.lastHash = _lastHash;
        sbi.parentHash = _parentHash;
        sbi.submitted = now;
        sbi.status = Status.Approved;
        sbi.currChallenge = 0;
        sbi.numChallenges = 0;
        NewSuperblock(id);
        bestSuperblock = id;
        accumulatedWork = _accumulatedWork;
        ApprovedSuperblock(id);
        return ERR_SUPERBLOCK_OK;
    }

    function proposeSuperblock(bytes32 _blocksMerkleRoot, uint _accumulatedWork, uint _timestamp, bytes32 _lastHash, bytes32 _parentHash) public returns (uint) {
        //++indexLastSubmit;
        bytes32 id = keccak256(_blocksMerkleRoot, _accumulatedWork, _timestamp, _lastHash, _parentHash);
        SuperblockInfo storage sbi = superblocks[id];
        // Make sure it was not submitted
        if (sbi.status != Status.Unitialized) {
            ErrorSuperblock(id, ERR_SUPERBLOCK_EXIST);
            return ERR_SUPERBLOCK_EXIST;
        }
        //indices[indexLastSubmit] = id;
        sbi.blocksMerkleRoot = _blocksMerkleRoot;
        sbi.accumulatedWork = _accumulatedWork;
        sbi.timestamp = _timestamp;
        sbi.lastHash = _lastHash;
        sbi.parentHash = _parentHash;
        sbi.submitted = now;
        sbi.status = Status.New;
        sbi.currChallenge = 0;
        sbi.numChallenges = 0;
        NewSuperblock(id);
        return ERR_SUPERBLOCK_OK;
    }

    function confirmSuperblock(bytes32 id) public returns (uint) {
        // TODO verify authorised msg.sender
        SuperblockInfo storage sbi = superblocks[id];
        if (sbi.status != Status.New) {
            ErrorSuperblock(id, ERR_SUPERBLOCK_BAD_STATUS);
            return ERR_SUPERBLOCK_BAD_STATUS;
        }
        if (now - sbi.submitted < SUPERBLOCK_PERIOD) {
            ErrorSuperblock(id, ERR_SUPERBLOCK_TIMEOUT);
            return ERR_SUPERBLOCK_TIMEOUT;
        }
        sbi.status = Status.Approved;
        if (sbi.accumulatedWork > accumulatedWork) {
            bestSuperblock = id;
            accumulatedWork = sbi.accumulatedWork;
        }
        ApprovedSuperblock(id);
        return ERR_SUPERBLOCK_OK;
    }

    function challengeSuperblock(bytes32 id) public returns (uint) {
        SuperblockInfo storage sbi = superblocks[id];
        if (sbi.status != Status.New && sbi.status != Status.InBattle) {
            ErrorSuperblock(id, ERR_SUPERBLOCK_BAD_STATUS);
            return ERR_SUPERBLOCK_BAD_STATUS;
        }
        sbi.status = Status.InBattle;
        ChallengeSuperblock(id, msg.sender);
        return ERR_SUPERBLOCK_OK;
    }

    // Getters

    function getBestSuperblock() public view returns (bytes32) {
        return bestSuperblock;
    }

    function getSuperblock(bytes32 id) public view returns (bytes32, uint, uint, bytes32, bytes32, uint, Status) {
        SuperblockInfo storage sbi = superblocks[id];
        return (sbi.blocksMerkleRoot, sbi.accumulatedWork, sbi.timestamp, sbi.lastHash, sbi.parentHash, sbi.submitted, sbi.status);
    }

}
