const crypto = require('crypto');
const keccak256 = require('js-sha3').keccak256;
const utils = require('./utils');
const Superblocks = artifacts.require('Superblocks');

contract('Superblocks', (accounts) => {
  let superblocks;
  let id0;
  let id1;
  let id2;
  let id3;
  before(async () => {
    superblocks = await Superblocks.deployed();
  });
  describe('Utils', () => {
    let hash;
    it('Make merkle', async () => {
      hash = await superblocks.makeMerkle([]);
      assert.equal(hash, utils.makeMerkle([]), 'Empty array');
      const twoArray = ['0x0000000000000000000000000000000000000000000000000000000000000001', '0x0000000000000000000000000000000000000000000000000000000000000002'];
      hash = await superblocks.makeMerkle(twoArray);
      assert.equal(hash, utils.makeMerkle(twoArray), 'Two items array');
      const threeArray = ['0x0000000000000000000000000000000000000000000000000000000000000001', '0x0000000000000000000000000000000000000000000000000000000000000002', '0x0000000000000000000000000000000000000000000000000000000000000003'];
      hash = await superblocks.makeMerkle(threeArray);
      assert.equal(hash, utils.makeMerkle(threeArray), 'Two items array');
      const hashes = [];
      for (let i=0; i<15; i++) {
        hashes.push(`0x${crypto.randomBytes(32).toString('hex')}`);
      }
      hash = await superblocks.makeMerkle(hashes);
      assert.equal(hash, utils.makeMerkle(hashes), 'Fifteen items array');
    });
  });
  describe('Statuses', () => {
    const merkleRoot = utils.makeMerkle([]);
    const accumulatedWork = 0;
    const timestamp = (new Date()).getTime() / 1000;
    const lastHash = '0x00';
    const parentHash = '0x00';
    it('Initialized', async () => {
      const result = await superblocks.initialize(merkleRoot, accumulatedWork, timestamp, lastHash, parentHash);
      assert.equal(result.logs[0].event, 'NewSuperblock', 'New superblock proposed');
      id0 = result.logs[0].args.superblockId;
    });
    it('Propose', async () => {
      const result = await superblocks.propose(merkleRoot, accumulatedWork, timestamp, lastHash, id0);
      // console.log(JSON.stringify(result, null, '  '));
      assert.equal(result.logs[0].event, 'NewSuperblock', 'New superblock proposed');
      id1 = result.logs[0].args.superblockId;
    });
    it('Bad propose', async () => {
      const result = await superblocks.propose(merkleRoot, accumulatedWork, timestamp, lastHash, id0);
      assert.equal(result.logs[0].event, 'ErrorSuperblock', 'Superblock already exists');
    });
    it('Approve', async () => {
      const result = await superblocks.confirm(id1);
      // console.log(JSON.stringify(result, null, '  '));
      assert.equal(result.logs[0].event, 'ApprovedSuperblock', 'Superblock confirmed');
    });
    it('Propose bis', async () => {
      const result = await superblocks.propose(merkleRoot, accumulatedWork, timestamp, lastHash, id1);
      assert.equal(result.logs[0].event, 'NewSuperblock', 'New superblock proposed');
      id2 = result.logs[0].args.superblockId;
    });
    it('Challenge', async () => {
      const result = await superblocks.challenge(id2);
      assert.equal(result.logs[0].event, 'ChallengeSuperblock', 'Superblock challenged');
      // id2 = result.logs[0].args.superblockId;
    });
    it('Semi-Approve', async () => {
      const result = await superblocks.semiApprove(id2);
      assert.equal(result.logs[0].event, 'SemiApprovedSuperblock', 'Superblock semi-approved');
      // id2 = result.logs[0].args.superblockId;
    });
    it('Approve bis', async () => {
      const result = await superblocks.confirm(id2);
      // console.log(JSON.stringify(result, null, '  '));
      assert.equal(result.logs[0].event, 'ApprovedSuperblock', 'Superblock confirmed');
    });
    it('Invalidate bad', async () => {
      const result = await superblocks.invalidate(id2);
      assert.equal(result.logs[0].event, 'ErrorSuperblock', 'Superblock cannot invalidate');
      // id2 = result.logs[0].args.superblockId;
    });
    it('Propose tris', async () => {
      const result = await superblocks.propose(merkleRoot, accumulatedWork, timestamp, lastHash, id2);
      assert.equal(result.logs[0].event, 'NewSuperblock', 'New superblock proposed');
      id3 = result.logs[0].args.superblockId;
    });
    it('Challenge bis', async () => {
      const result = await superblocks.challenge(id3);
      assert.equal(result.logs[0].event, 'ChallengeSuperblock', 'Superblock challenged');
      // id2 = result.logs[0].args.superblockId;
    });
    it('Invalidate', async () => {
      const result = await superblocks.invalidate(id3);
      assert.equal(result.logs[0].event, 'InvalidSuperblock', 'Superblock invalidated');
      // id2 = result.logs[0].args.superblockId;
    });
    it('Approve bad', async () => {
      const result = await superblocks.confirm(id3);
      // console.log(JSON.stringify(result, null, '  '));
      assert.equal(result.logs[0].event, 'ErrorSuperblock', 'Superblock cannot approve');
    });
  });
});
