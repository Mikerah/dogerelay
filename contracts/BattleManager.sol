pragma solidity ^0.4.0;

contract BattleManager {

    event NewSession(bytes32 sessionId, address claimant, address challenger);
    event NewQuery(bytes32 sessionId, address claimant);
    event NewResponse(bytes32 sessionId, address challenger);
    event ChallengerConvicted(bytes32 sessionId, address challenger);
    event ClaimantConvicted(bytes32 sessionId, address claimant);

    uint constant responseTime = 1 hours;

    struct BattleSession {
        bytes32 id;
        bytes32 claimId;
        address claimant;
        address challenger;
        //bytes input;
        //bytes output;
        uint lastClaimantMessage;
        uint lastChallengerMessage;
        //uint lowStep;
        //bytes32 lowHash;
        //uint medStep;
        //bytes32 medHash;
        //uint highStep;
        //bytes32 highHash;
    }

    modifier onlyClaimant(bytes32 sessionId) {
        require(msg.sender == sessions[sessionId].claimant);
        _;
    }

    modifier onlyChallenger(bytes32 sessionId) {
        require(msg.sender == sessions[sessionId].challenger);
        _;
    }

    mapping(bytes32 => BattleSession) public sessions;

    uint sessionsCount = 0;

    function beginBattleSession(
        bytes32 claimId,
        address challenger,
        address claimant
    )
        public
        returns (bytes32)
    {
        bytes32 sessionId = bytes32(sessionsCount+1);
        BattleSession storage s = sessions[sessionId];
        s.id = sessionId;
        s.claimId = claimId;
        // sessionsClaimId[sessionId] = claimId;
        s.claimant = claimant;
        s.challenger = challenger;
        // s.input = _input;
        //s.output = _output;
        s.lastClaimantMessage = now;
        s.lastChallengerMessage = now;
        //s.lowStep = 0;
        //s.lowHash = keccak256(_input);
        //s.medStep = 0;
        //s.medHash = bytes32(0);
        //s.highStep = steps;
        //s.highHash = keccak256(_output);

        // require(isInitiallyValid(s));
        sessionsCount+=1;

        emit NewSession(sessionId, claimant, challenger);
        return sessionId;
    }

    function query(bytes32 sessionId, uint step)
        onlyChallenger(sessionId)
        public
    {
        BattleSession storage s = sessions[sessionId];
        bytes32 claimId = s.claimId;
        // SuperblockClaim claim = claims[claimId];
        if (step == 0) {

        }

        s.lastChallengerMessage = now;
        emit NewQuery(sessionId, s.claimant);
    }

    function respond(bytes32 sessionId, uint step, bytes32 hash)
        onlyClaimant(sessionId)
        public
    {
        BattleSession storage s = sessions[sessionId];
        s.lastClaimantMessage = now;
        emit NewResponse(sessionId, s.challenger);
    }

    //Able to trigger conviction if time of response is too high
    function timeout(bytes32 sessionId, bytes32 claimId)
        public
    {
        BattleSession storage session = sessions[sessionId];
        require(session.claimant != 0);
        if (
            session.lastChallengerMessage > session.lastClaimantMessage &&
            now > session.lastChallengerMessage + responseTime
        ) {
            claimantConvicted(sessionId, session.claimant, claimId);
        } else if (
            session.lastClaimantMessage > session.lastChallengerMessage &&
            now > session.lastClaimantMessage + responseTime
        ) {
            challengerConvicted(sessionId, session.challenger, claimId);
        } else {
            require(false);
        }
    }

    function sessionDecided(bytes32 sessionId, bytes32 claimId, address winner, address loser) internal;

    function challengerConvicted(bytes32 sessionId, address challenger, bytes32 claimId)
        internal
    {
        BattleSession storage s = sessions[sessionId];
        sessionDecided(sessionId, claimId, s.claimant, s.challenger);
        disable(sessionId);
        emit ChallengerConvicted(sessionId, challenger);
    }

    function claimantConvicted(bytes32 sessionId, address claimant, bytes32 claimId)
        internal
    {
        BattleSession storage s = sessions[sessionId];
        sessionDecided(sessionId, claimId, s.challenger, s.claimant);
        disable(sessionId);
        emit ClaimantConvicted(sessionId, claimant);
    }

    function disable(bytes32 sessionId)
        internal
    {
        delete sessions[sessionId];
    }
}
