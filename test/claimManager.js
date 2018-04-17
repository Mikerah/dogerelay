const utils = require('./utils');
const ClaimManager = artifacts.require('ClaimManager');


contract('ClaimManager', (accounts) => {
  let claimManager;
  let id0;
  let id1;
  let id2;
  let claimId1;
  let sessionId1;
  const owner = accounts[0];
  const submitter = accounts[1];
  const challenger = accounts[2];
  const hashes = [];
  const rootHash = utils.makeMerkle(hashes);
  describe('Session', () => {
    const merkleRoot = utils.makeMerkle([]);
    const accumulatedWork = 0;
    const timestamp = (new Date()).getTime() / 1000;
    const lastHash = '0x00';
    const parentHash = '0x00';
    before(async () => {
      claimManager = await ClaimManager.deployed();
    });
    it('Initialized', async () => {
      const result = await claimManager.initialize(merkleRoot, accumulatedWork, timestamp, lastHash, parentHash, { from: owner });
      assert.equal(result.logs[0].event, 'NewSuperblock', 'New superblock proposed');
      // console.log(JSON.stringify(result, null, '  '));
      id0 = result.logs[0].args.superblockId;
    });
    it('Deposit', async () => {
      //FIXME: ganache-cli creates the same transaction hash if two account send the same amount
      let result = await claimManager.makeDeposit({ value: 10, from: submitter });
      assert.equal(result.logs[0].event, 'DepositMade', 'Submitter deposit made');
      result = await claimManager.makeDeposit({ value: 11, from: challenger });
      assert.equal(result.logs[0].event, 'DepositMade', 'Challenger deposit made');
    });
    it('Propose', async () => {
      const best = await claimManager.getBestSuperblock();
      assert.equal(id0, best, 'Best superblock should match');
      const parentHash = id0;
      //console.log(parentHash);
      const result = await claimManager.proposeSuperblock(merkleRoot, accumulatedWork, timestamp, lastHash, parentHash, { from: submitter });
      //console.log(JSON.stringify(result, null, '  '));
      assert.equal(result.logs[0].event, 'NewSuperblock', 'New superblock proposed');
      id1 = result.logs[0].args.superblockId;
    });
    it('Challenge', async () => {
      const result = await claimManager.challengeSuperblock(id1, { from: challenger });
      // console.log(JSON.stringify(result, null, '  '));
      assert.equal(result.logs[2].event, 'ClaimChallenged', 'Superblock challenged');
      claimId1 = result.logs[2].args.claimID;
    });
    it('Start Battle', async () => {
      const result = await claimManager.runNextVerificationGame(claimId1, { from: submitter });
      //console.log(JSON.stringify(result, null, '  '));
      assert.equal(result.logs[1].event, 'VerificationGameStarted', 'Verification battle started');
      sessionId1 = result.logs[1].args.sessionId;
    });
    it('Verify session', async () => {
      const session = await claimManager.getSession(claimId1, challenger);
      // console.log(JSON.stringify(result, null, '  '));
      assert.equal(session, sessionId1, 'Sessions should match');
      await claimManager.query(sessionId1, 0, { from: challenger });

    });
  });
});
