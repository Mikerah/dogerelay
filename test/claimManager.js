const ClaimManager = artifacts.require('ClaimManager');


contract('ClaimManager', (accounts) => {
  let claimManager;
  let id0;
  let id1;
  let id2;
  before(async () => {
    claimManager = await ClaimManager.deployed();
  });
  it('Initialized', async () => {
    const result = await claimManager.initialize("0x01", "0x02", "0x03", "0x04", "0x00");
    assert.equal(result.logs[0].event, 'NewSuperblock', 'New superblock proposed');
    id0 = result.logs[0].args.superblockId;
  });
  it('Propose', async () => {
    const result = await claimManager.proposeSuperblock("0x01", "0x02", "0x03", "0x04", id0);
    // console.log(JSON.stringify(result, null, '  '));
    assert.equal(result.logs[0].event, 'NewSuperblock', 'New superblock proposed');
    id1 = result.logs[0].args.superblockId;
  });
  it('Bad propose', async () => {
    const result = await claimManager.proposeSuperblock("0x01", "0x02", "0x03", "0x04", id0);
    assert.equal(result.logs[0].event, 'ErrorSuperblock', 'Superblock already exists');
  });
  it('Approve', async () => {
    const result = await claimManager.confirmSuperblock(id1);
    // console.log(JSON.stringify(result, null, '  '));
    assert.equal(result.logs[0].event, 'ApprovedSuperblock', 'Superblock confirmed');
  });
  it('Propose bis', async () => {
    const result = await claimManager.proposeSuperblock("0x01", "0x02", "0x03", "0x04", id1);
    assert.equal(result.logs[0].event, 'NewSuperblock', 'New superblock proposed');
    id2 = result.logs[0].args.superblockId;
  });
  it('Challenge', async () => {
    const result = await claimManager.challengeSuperblock(id2);
    // console.log(JSON.stringify(result, null, '  '));
    assert.equal(result.logs[0].event, 'ChallengeSuperblock', 'Superblock challenged');
    id2 = result.logs[0].args.superblockId;
  });
});
