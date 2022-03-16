import {ethers} from 'hardhat';
import {Signer, BigNumber} from 'ethers';
import {expect} from 'chai';
import {TransactionResponse} from '@ethersproject/abstract-provider';

describe('VLXNFT Mint', function () {
  let VlxNft: any;
  let nftmint: any;
  let account: any;
  const royalty = 250;
  const NEW_TOKEN_ID = '1';
  const TOKEN_URI = 'http://example.com/ip_records/42';

  beforeEach(async function () {
    [account] = await ethers.getSigners();
    VlxNft = await ethers.getContractFactory('VLXNFT');
    nftmint = await VlxNft.deploy('STAR', 'VLX');
  });

  async function mintNftDefault(): Promise<TransactionResponse> {
    return nftmint.mint(TOKEN_URI);
  }

  it('Should set the right owner', async function () {
    expect(await nftmint.owner()).to.equal(account.address);
  });

  it('should match addresses correctly', async function () {
    const mint = await nftmint.mint(TOKEN_URI);
    expect(mint.from).to.equal(account.address);
    expect(mint.to).to.equal(nftmint.address);
  });

  it('should get token ID', async () => {
    const mint = await nftmint.mint(TOKEN_URI);
    const receipt = await mint.wait();
    for (const event of receipt.events) {
      if (event.event !== 'Transfer') {
        console.log('ignoring unknown event type ', event.event);
        continue;
      }
      expect(event.args.tokenId.toString()).to.equal(NEW_TOKEN_ID);
    }
  });

  it('should get owner address', async () => {
    await mintNftDefault();
    const owner = await nftmint.getCreator(1);
    expect(owner).to.equal(account.address);
  });

  it('emits the Transfer event', async () => {
    await expect(mintNftDefault())
      .to.emit(nftmint, 'Transfer')
      .withArgs(ethers.constants.AddressZero, account.address, NEW_TOKEN_ID);
  });

  it('Should assign the NFT token to the owner', async function () {
    await mintNftDefault();
    const ownerBalance = await nftmint.balanceOf(account.address);
    expect(ownerBalance).to.equal(1);
  });

  it('increments the item ID', async () => {
    const STARTING_NEW_ITEM_ID = '1';
    const NEXT_NEW_ITEM_ID = '2';

    await expect(mintNftDefault())
      .to.emit(nftmint, 'Transfer')
      .withArgs(ethers.constants.AddressZero, account.address, STARTING_NEW_ITEM_ID);

    await expect(mintNftDefault())
      .to.emit(nftmint, 'Transfer')
      .withArgs(ethers.constants.AddressZero, account.address, NEXT_NEW_ITEM_ID);
  });

  it('Should be set royalty correctly', async () => {
    await nftmint.setRoyalty(royalty);
    expect(await nftmint.getRoyalty()).to.equal(BigNumber.from(royalty));
  });

  it('Should be set royalty 0 to 10%', async () => {
    await expect(nftmint.setRoyalty(1100)).to.be.revertedWith('Royalty must be between 0 and 10%');
  });
});
