pragma solidity ^0.4.0;

import {DepositsManager} from './DepositsManager.sol';
import {Superblocks} from './Superblocks.sol';
import {BattleManager} from './BattleManager.sol';


// ClaimManager: queues a sequence of challengers to play with a claimant.

contract ClaimManager is DepositsManager, Superblocks, BattleManager {
    uint private numClaims = 1;     // index as key for the claims mapping.
    uint public minDeposit = 1;    // TODO: what should the minimum deposit be?

    // default initial amount of blocks for challenge timeout
    uint public defaultChallengeTimeout = 5;

    event DepositBonded(bytes32 claimID, address account, uint amount);
    event DepositUnbonded(bytes32 claimID, address account, uint amount);
    //event ClaimCreated(uint claimID, address claimant, bytes plaintext, bytes blockHash);
    event ClaimCreated(bytes32 claimID, address claimant, bytes32 superblockId);
    event ClaimChallenged(bytes32 claimID, address challenger);
    event SessionDecided(bytes32 sessionId, address winner, address loser);
    event ClaimSuccessful(bytes32 claimID, address claimant, bytes32 superblockId);
    event ClaimFailed(bytes32 claimID, address claimant, bytes32 superblockId);
    event VerificationGameStarted(bytes32 claimID, address claimant, address challenger, bytes32 sessionId);//Rename to SessionStarted?
    //event ClaimVerificationGamesEnded(uint claimID);

    struct SuperblockClaim {
        address claimant;
        //bytes plaintext;    // the plaintext Dogecoin block header.
        //bytes blockHash;    // the Dogecoin blockhash.
        uint createdAt;     // the block number at which the claim was created.
        address[] challengers;      // all current challengers.
        mapping(address => bytes32) sessions; //map challengers to sessionId's
        uint numChallengers; // is number of challengers always same as challengers.length ?
        uint currentChallenger;    // index of next challenger to play a verification game.
        bool verificationOngoing;   // is the claim waiting for results from an ongoing verificationg game.
        mapping (address => uint) bondedDeposits;   // all deposits bonded in this claim.
        bool decided;
        uint challengeTimeoutBlockNumber;
        //bytes32 proposalId;
        //IScryptDependent scryptDependent;
        bytes32 superblockId;
    }

  //  mapping(address => uint) public claimantClaims;
    mapping(bytes32 => SuperblockClaim) private claims;

    modifier onlyBy(address _account) {
        require(msg.sender == _account);
        _;
    }

    // @dev – the constructor
    function ClaimManager() public {
    }

    // @dev – locks up part of the a user's deposit into a claim.
    // @param claimID – the claim id.
    // @param account – the user's address.
    // @param amount – the amount of deposit to lock up.
    // @return – the user's deposit bonded for the claim.
    function bondDeposit(bytes32 claimID, address account, uint amount) private returns (uint) {
        SuperblockClaim storage claim = claims[claimID];

        require(claimExists(claim));
        require(deposits[account] >= amount);
        deposits[account] -= amount;

        claim.bondedDeposits[account] += amount;
        emit DepositBonded(claimID, account, amount);
        return claim.bondedDeposits[account];
    }

    // @dev – accessor for a claims bonded deposits.
    // @param claimID – the claim id.
    // @param account – the user's address.
    // @return – the user's deposit bonded for the claim.
    function getBondedDeposit(bytes32 claimID, address account) public view returns (uint) {
        SuperblockClaim storage claim = claims[claimID];
        require(claimExists(claim));
        return claim.bondedDeposits[account];
    }

    // @dev – unlocks a user's bonded deposits from a claim.
    // @param claimID – the claim id.
    // @param account – the user's address.
    // @return – the user's deposit which was unbonded from the claim.
    function unbondDeposit(bytes32 claimID, address account) public returns (uint) {
        SuperblockClaim storage claim = claims[claimID];
        require(claimExists(claim));
        require(claim.decided == true);

        uint bondedDeposit = claim.bondedDeposits[account];

        delete claim.bondedDeposits[account];
        deposits[account] += bondedDeposit;

        emit DepositUnbonded(claimID, account, bondedDeposit);

        return bondedDeposit;
    }

    // @dev – check whether a DogeCoin blockHash was calculated correctly from the plaintext block header.
    // only callable by the DogeRelay contract.
    // @param _plaintext – the plaintext blockHeader.
    // @param _blockHash – the blockHash.
    // @param claimant – the address of the Dogecoin block submitter.
    function proposeSuperblock(bytes32 _blocksMerkleRoot, uint _accumulatedWork, uint _timestamp, bytes32 _lastHash, bytes32 _parentHash) public returns (uint, bytes32) {
        address _submitter = msg.sender;

        if (deposits[_submitter] < minDeposit) {
            return (ERR_SUPERBLOCK_MIN_DEPOSIT, 0);
        }

        uint err;
        bytes32 superblockId;
        (err, superblockId) = propose(_blocksMerkleRoot, _accumulatedWork, _timestamp, _lastHash, _parentHash);
        if (err != 0) {
            return (err, superblockId);
        }

        bytes32 claimId = superblockId;
        require(!claimExists(claims[claimId]));

        SuperblockClaim storage claim = claims[claimId];
        claim.claimant = _submitter;
        claim.numChallengers = 0;
        claim.currentChallenger = 0;
        claim.decided = false;
        claim.verificationOngoing = false;
        claim.createdAt = block.number;
        claim.superblockId = superblockId;

        bondDeposit(claimId, claim.claimant, minDeposit);
        emit ClaimCreated(claimId, claim.claimant, superblockId);

        return (ERR_SUPERBLOCK_OK, superblockId);
    }

    // @dev – challenge an existing Scrypt claim.
    // triggers a downstream claim computation on the scryptVerifier contract
    // where the claimant & the challenger will immediately begin playing a verification.
    //
    // @param claimID – the claim ID.
    function challengeSuperblock(bytes32 superblockId) public returns (uint, bytes32) {
        bytes32 claimID = superblockId;
        SuperblockClaim storage claim = claims[claimID];

        require(claimExists(claim));
        require(!claim.decided);
        require(claim.sessions[msg.sender] == 0);

        require(deposits[msg.sender] >= minDeposit);
        bondDeposit(claimID, msg.sender, minDeposit);

        uint err;
        (err, ) = challenge(superblockId);
        if (err != 0) {
            return (err, 0);
        }

        claim.challengeTimeoutBlockNumber += defaultChallengeTimeout;
        claim.challengers.push(msg.sender);
        claim.numChallengers += 1;
        emit ClaimChallenged(claimID, msg.sender);

        return (ERR_SUPERBLOCK_OK, superblockId);
    }

    // @dev – runs a verification game between the claimant and
    // the next queued-up challenger.
    // @param claimID – the claim id.
    function runNextVerificationGame(bytes32 claimID) public {
        SuperblockClaim storage claim = claims[claimID];

        require(claimExists(claim));
        require(!claim.decided);

        require(claim.verificationOngoing == false);

        // check if there is a challenger who has not the played verification game yet.
        if (claim.numChallengers > claim.currentChallenger) {

            // kick off a verification game.
            // uint sessionId = scryptVerifier.claimComputation(claimID, claim.challengers[claim.currentChallenger], claim.claimant, claim.plaintext, claim.blockHash, 2049);
            bytes32 sessionId = beginBattleSession(claimID, claim.challengers[claim.currentChallenger], claim.claimant);

            claim.sessions[claim.challengers[claim.currentChallenger]] = sessionId;
            emit VerificationGameStarted(claimID, claim.claimant, claim.challengers[claim.currentChallenger], sessionId);

            claim.verificationOngoing = true;
            claim.currentChallenger += 1;
        } else {

        }
    }

    // @dev – called when a verification game has ended.
    // only callable by the scryptVerifier contract.
    //
    // @param sessionId – the sessionId.
    // @param winner – winner of the verification game.
    // @param loser – loser of the verification game.
    /* function sessionDecided(bytes32 sessionId, bytes32 claimID, address winner, address loser) onlyBy(address(scryptVerifier)) public {
        SuperblockClaim storage claim = claims[claimID];

        require(claimExists(claim));

        //require(claim.verificationOngoing == true);
        claim.verificationOngoing = false;

        //TODO Fix reward splitting
        // reward the winner, with the loser's bonded deposit.
        //uint depositToTransfer = claim.bondedDeposits[loser];
        //claim.bondedDeposits[winner] += depositToTransfer;
        //delete claim.bondedDeposits[loser];

        if (claim.claimant == loser) {
            // the claim is over.
            // note: no callback needed to the DogeRelay contract,
            // because it by default does not save blocks.

            //Trigger end of verification game
            claim.numChallengers = 0;
            runNextVerificationGame(claimID);
        } else if (claim.claimant == winner) {
            // the claim continues.
            runNextVerificationGame(claimID);
        } else {
            revert();
        }

        emit SessionDecided(sessionId, winner, loser);
    } */

    // @dev – check whether a claim has successfully withstood all challenges.
    // if successful, it will trigger a callback to the DogeRelay contract,
    // notifying it that the Scrypt blockhash was correctly calculated.
    //
    // @param claimID – the claim ID.
    function checkClaimFinished(bytes32 claimID) public {
        SuperblockClaim storage claim = claims[claimID];

        require(claimExists(claim));

        // check that there is no ongoing verification game.
        require(claim.verificationOngoing == false);

        // check that the claim has exceeded the default challenge timeout.
        require(block.number -  claim.createdAt > defaultChallengeTimeout);

        //check that the claim has exceeded the claim's specific challenge timeout.
        require(block.number > claim.challengeTimeoutBlockNumber);

        // check that all verification games have been played.
        require(claim.numChallengers <= claim.currentChallenger);

        claim.decided = true;

        // IScryptDependent(claim.scryptDependent).scryptVerified(claim.proposalId);

        unbondDeposit(claimID, claim.claimant);

        emit ClaimSuccessful(claimID, claim.claimant, claim.superblockId);
    }

    function claimExists(SuperblockClaim claim) pure private returns(bool) {
        return claim.claimant != 0x0;
    }

    /* function firstChallenger(bytes32 claimID) public view returns(address) {
        require(claimID < numClaims);
        return claims[claimID].challengers[0];
    }

    function createdAt(bytes32 claimID) public view returns(uint) {
        //require(claimID < numClaims);
        return claims[claimID].createdAt;
    } */

    function getSession(bytes32 claimID, address challenger) public view returns(bytes32) {
        return claims[claimID].sessions[challenger];
    }

    /* function getChallengers(bytes32 claimID) public view returns(address[]) {
        return claims[claimID].challengers;
    }

    function getCurrentChallenger(bytes32 claimID) public view returns(address) {
        return claims[claimID].challengers[claims[claimID].currentChallenger];
    }

    function getVerificationOngoing(bytes32 claimID) public view returns(bool) {
        return claims[claimID].verificationOngoing;
    } */

    /* function getClaim(uint claimID)
        public
        view
        returns(address claimant, bytes plaintext, bytes blockHash, bytes32 proposalId)
    {
        SuperblockClaim storage claim = claims[claimID];

        return (
            claim.claimant,
            claim.plaintext,
            claim.blockHash,
            claim.proposalId
        );
    } */

    /* function getClaimReady(uint claimID) public view returns(bool) {
        SuperblockClaim storage claim = claims[claimID];

        // check that the claim exists
        bool exists = claimExists(claim);

        // check that the claim has exceeded the default challenge timeout.
        bool pastChallengeTimeout = block.number.sub(claim.createdAt) > defaultChallengeTimeout;

        // check that the claim has exceeded the claim's specific challenge timeout.
        bool pastClaimTimeout = block.number > claim.challengeTimeoutBlockNumber;

        // check that there is no ongoing verification game.
        bool noOngoingGames = claim.verificationOngoing == false;

        // check that all verification games have been played.
        bool noPendingGames = claim.numChallengers == claim.currentChallenger;

        return exists && pastChallengeTimeout && pastClaimTimeout && noOngoingGames && noPendingGames;
    } */
}
