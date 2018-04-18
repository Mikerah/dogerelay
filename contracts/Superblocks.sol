pragma solidity ^0.4.19;

import {ErrorCodes} from "./ErrorCodes.sol";

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
        Status status;
    }

    // Mapping superblock id => superblock data
    mapping (bytes32 => SuperblockInfo) superblocks;

    bytes32 bestSuperblock;
    uint accumulatedWork;

    //TODO: Add 'indexed' to parameters
    event NewSuperblock(bytes32 superblockId, address who);
    event ApprovedSuperblock(bytes32 superblockId, address who);
    event ChallengeSuperblock(bytes32 superblockId, address who);
    event SemiApprovedSuperblock(bytes32 superblockId, address who);
    event InvalidSuperblock(bytes32 superblockId, address who);

    event ErrorSuperblock(bytes32 superblockId, uint err);

    function Superblock() public {
    }

    function initialize(bytes32 _blocksMerkleRoot, uint _accumulatedWork, uint _timestamp, bytes32 _lastHash, bytes32 _parentHash) public returns (uint, bytes32) {
        //require(_parentHash == bytes32(0));
        bytes32 superblockId = keccak256(_blocksMerkleRoot, _accumulatedWork, _timestamp, _lastHash, _parentHash);

        SuperblockInfo storage sbi = superblocks[superblockId];

        require(sbi.status == Status.Unitialized);
        require(_parentHash == 0);

        sbi.blocksMerkleRoot = _blocksMerkleRoot;
        sbi.accumulatedWork = _accumulatedWork;
        sbi.timestamp = _timestamp;
        sbi.lastHash = _lastHash;
        sbi.parentHash = _parentHash;
        sbi.submitter = msg.sender;
        sbi.status = Status.Approved;

        emit NewSuperblock(superblockId, msg.sender);

        bestSuperblock = superblockId;
        accumulatedWork = _accumulatedWork;

        emit ApprovedSuperblock(superblockId, msg.sender);

        return (ErrorCodes.ERR_SUPERBLOCK_OK, superblockId);
    }

    function propose(bytes32 _blocksMerkleRoot, uint _accumulatedWork, uint _timestamp, bytes32 _lastHash, bytes32 _parentHash) public returns (uint, bytes32) {
        //log4(_blocksMerkleRoot, bytes32(_accumulatedWork), bytes32(_timestamp), _lastHash, _parentHash);
        SuperblockInfo storage parent = superblocks[_parentHash];
        //log1(_parentHash, bytes32(uint(parent.status)));
        if (parent.status != Status.SemiApproved && parent.status != Status.Approved) {
            emit ErrorSuperblock(superblockId, ERR_SUPERBLOCK_BAD_PARENT);
            return (ERR_SUPERBLOCK_BAD_PARENT, 0);
        }

        bytes32 superblockId = keccak256(_blocksMerkleRoot, _accumulatedWork, _timestamp, _lastHash, _parentHash);
        SuperblockInfo storage sbi = superblocks[superblockId];
        if (sbi.status != Status.Unitialized) {
            emit ErrorSuperblock(superblockId, ERR_SUPERBLOCK_EXIST);
            return (ERR_SUPERBLOCK_EXIST, 0);
        }

        sbi.blocksMerkleRoot = _blocksMerkleRoot;
        sbi.accumulatedWork = _accumulatedWork;
        sbi.timestamp = _timestamp;
        sbi.lastHash = _lastHash;
        sbi.parentHash = _parentHash;
        sbi.submitter = msg.sender;
        sbi.status = Status.New;

        emit NewSuperblock(superblockId, msg.sender);

        return (ErrorCodes.ERR_SUPERBLOCK_OK, superblockId);
    }

    function confirm(bytes32 superblockId) public returns (uint, bytes32) {
        //TODO: verify authorised msg.sender
        SuperblockInfo storage sbi = superblocks[superblockId];
        if (sbi.status != Status.New && sbi.status != Status.SemiApproved) {
            emit ErrorSuperblock(superblockId, ERR_SUPERBLOCK_BAD_STATUS);
            return (ERR_SUPERBLOCK_BAD_STATUS, 0);
        }
        // Parent must be approved
        SuperblockInfo storage parent = superblocks[sbi.parentHash];
        if (parent.status != Status.Approved) {
            emit ErrorSuperblock(superblockId, ERR_SUPERBLOCK_BAD_PARENT);
            return (ERR_SUPERBLOCK_BAD_PARENT, 0);
        }
        sbi.status = Status.Approved;
        if (sbi.accumulatedWork > accumulatedWork) {
            bestSuperblock = superblockId;
            accumulatedWork = sbi.accumulatedWork;
        }
        emit ApprovedSuperblock(superblockId, msg.sender);
        return (ERR_SUPERBLOCK_OK, superblockId);
    }

    function challenge(bytes32 superblockId) public returns (uint, bytes32) {
        SuperblockInfo storage sbi = superblocks[superblockId];
        // We can challenge new superblocks or blocks being challenged
        if (sbi.status != Status.New && sbi.status != Status.InBattle) {
            emit ErrorSuperblock(superblockId, ERR_SUPERBLOCK_BAD_STATUS);
            return (ERR_SUPERBLOCK_BAD_STATUS, 0);
        }
        sbi.status = Status.InBattle;
        emit ChallengeSuperblock(superblockId, msg.sender);
        return (ERR_SUPERBLOCK_OK, superblockId);
    }

    function semiApprove(bytes32 superblockId) public returns (uint) {
        SuperblockInfo storage sbi = superblocks[superblockId];
        if (sbi.status != Status.InBattle) {
            emit ErrorSuperblock(superblockId, ERR_SUPERBLOCK_BAD_STATUS);
            return ERR_SUPERBLOCK_BAD_STATUS;
        }
        sbi.status = Status.SemiApproved;
        emit SemiApprovedSuperblock(superblockId, msg.sender);
        return ERR_SUPERBLOCK_OK;
    }

    function invalidate(bytes32 superblockId) public returns (uint) {
        SuperblockInfo storage sbi = superblocks[superblockId];
        if (sbi.status != Status.InBattle && sbi.status != Status.SemiApproved) {
            emit ErrorSuperblock(superblockId, ERR_SUPERBLOCK_BAD_STATUS);
            return ERR_SUPERBLOCK_BAD_STATUS;
        }
        sbi.status = Status.Invalid;
        emit InvalidSuperblock(superblockId, msg.sender);
        return ERR_SUPERBLOCK_OK;
    }

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
            0, // sbi.timeout,
            sbi.status
        );
    }
    function makeMerkle(bytes32[] hashes) public pure returns (bytes32) {
        uint length = hashes.length;
        if (length == 0) return sha256();
        uint i;
        uint j;
        uint k;
        while (length > 1) {
            k = 0;
            for (i = 0; i < length; i += 2) {
                j = i+1<length ? i+1 : length-1;
                hashes[k] = sha256(hashes[i], hashes[j]);
                k += 1;
            }
            length = k;
        }
        return hashes[0];
    }
}
