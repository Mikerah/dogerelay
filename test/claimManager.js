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
    const emptyMerkleRoot = utils.makeMerkle([]);
    const initAccumulatedWork = 0;
    const initTimestamp = (new Date()).getTime() / 1000;
    const initLastHash = '0x00';
    const initParentHash = '0x00';
    const hashes = [
      "0x0ce3bcd684f4f795e549a2ddd1f4c539e8d80813b232a448c56d6b28b74fe3ed",
      "0x03d7be19e9e961691712fde9fd87b706c7d0768a207b84ef6ad1f81ffa90dec5",
      "0x75520841e64a8acdd669e453d0a55caa7082a35ec6406cf5e73b30cdf34ad0b6",
      "0x6a4a7fdf807e56a39ca842d3e3807e6639af4cf1d05cf6da6154a0b5170f7690",
      "0xde3d260197746a0b509ffa4e05cc8b042f0a0ce472c20d75e17bf58815d395e1",
      "0x6bbe42a26ec5af04eb16da92131ddcd87df55d629d940eaa8f88c0ceb0b9ede6",
      "0x50ab8816b4a1ffa5700ff26bb1fbacce5e3cb93978e57410cfabbe8819a45a4e"
    ];
    const merkleRoot = utils.makeMerkle(hashes);
    before(async () => {
      claimManager = await ClaimManager.deployed();
    });
    it('Initialized', async () => {
      const result = await claimManager.initialize(emptyMerkleRoot, initAccumulatedWork, initTimestamp, initLastHash, initParentHash, { from: owner });
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
      const accumulatedWork = 1;
      const timestamp = (new Date()).getTime() / 1000;
      const lastHash = hashes[hashes.length - 1];
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
      claimId1 = result.logs[2].args.claimId;
    });
    it('Start Battle', async () => {
      const result = await claimManager.runNextVerificationGame(claimId1, { from: submitter });
      //console.log(JSON.stringify(result, null, '  '));
      assert.equal(result.logs[1].event, 'VerificationGameStarted', 'Verification battle started');
      sessionId1 = result.logs[1].args.sessionId;
    });
    it('Query hashes', async () => {
      const session = await claimManager.getSession(claimId1, challenger);
      // console.log(JSON.stringify(result, null, '  '));
      assert.equal(session, sessionId1, 'Sessions should match');
      await claimManager.query(sessionId1, 0, { from: challenger });
    });
    it('Verify hashes', async () => {
      const session = await claimManager.getSession(claimId1, challenger);
      // console.log(JSON.stringify(result, null, '  '));
      assert.equal(session, sessionId1, 'Sessions should match');
      const data = utils.hashesToData(hashes);
      await claimManager.respond(sessionId1, 0, data, { from: submitter });
    });
  });
});
