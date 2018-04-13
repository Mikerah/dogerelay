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
  describe('Session', () => {
    before(async () => {
      claimManager = await ClaimManager.deployed();
    });
    it('Initialized', async () => {
      const result = await claimManager.initialize("0x01", "0x02", "0x03", "0x04", "0x00", { from: owner });
      assert.equal(result.logs[0].event, 'NewSuperblock', 'New superblock proposed');
      id0 = result.logs[0].args.superblockId;
    });
    it('Deposit', async () => {
      let result = await claimManager.makeDeposit({ value: 10, from: submitter });
      assert.equal(result.logs[0].event, 'DepositMade', 'Submitter deposit made');
      result = await claimManager.makeDeposit({ value: 10, from: challenger });
      assert.equal(result.logs[0].event, 'DepositMade', 'Challenger deposit made');
    });
    it('Propose', async () => {
      const best = await claimManager.getBestSuperblock();
      assert.equal(id0, best, 'Best superblock should match');
      const result = await claimManager.proposeSuperblock("0x01", "0x02", "0x03", "0x04", id0, { from: submitter });
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
      claimManager.query(sessionId1, { from: challenger });
    });
  });
});
