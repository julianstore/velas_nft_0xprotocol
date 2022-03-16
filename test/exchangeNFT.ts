import {ethers} from 'hardhat';
import {expect} from 'chai';
import 'dotenv/config';
import BigNumber from 'bignumber.js';

interface Order {
  seller: any;
  buyer: any;
  maker: any;
  collection: any;
  tokenId: any;
  price: any;
  expiry: any;
  nonce: any;
  state: any;
}

describe('VLXNFT Exchange', function () {
  let account: any;
  let account1: any;
  let account2: any;
  let account3: any;
  let ExchangeNft: any;
  let ENft: any;
  let VlxNft: any;
  let nftmint: any;
  let provider: any;
  let order: any;
  let privateKey: any = process.env.HARDHAT_PRIVATE;
  let wallet = new ethers.Wallet(privateKey);
  let orderMsg: any;
  let messageHash: any;
  let messageHashBytes: any;
  let flatSig: any;
  const NEW_TOKEN_ID = '1';
  const price = ethers.utils.parseEther('100');
  const lowerPrice = ethers.utils.parseEther('10');
  const nftPlatformFee = 275;
  const TOKEN_URI = 'http://example.com/ip_records/42';
  const WETH = '0xc778417e063141139fce010982780140aa0cd5ab';
  const expiry = 1646900646;
  const nonce = 1;

  beforeEach(async function () {
    [account, account1, account2, account3] = await ethers.getSigners();

    provider = ethers.provider;
    VlxNft = await ethers.getContractFactory('VLXNFT');
    nftmint = await VlxNft.deploy('STAR', 'VLX');
    ExchangeNft = await ethers.getContractFactory('ExchangeNFT');
    ENft = await ExchangeNft.deploy(WETH, account1.address, account2.address);
    await ENft.setMarketingFee(nftPlatformFee);
    await ENft.addCollection(nftmint.address);
    await nftmint.setRoyalty(300);
    await nftmint.mint(TOKEN_URI);
    await nftmint.approve(ENft.address, NEW_TOKEN_ID);
    orderMsg = account1.address.concat(
      account2.address,
      account2.address,
      nftmint.address,
      NEW_TOKEN_ID,
      price,
      expiry,
      nonce,
      0,
    );

    messageHash = ethers.utils.id(orderMsg);
    messageHashBytes = ethers.utils.arrayify(messageHash);
    flatSig = await wallet.signMessage(messageHashBytes);
  });

  function setOrder(
    seller: any,
    buyer: any,
    maker: any,
    collection: any,
    tokenId: any,
    price: any,
    expiry: any,
    nonce: any,
    state: any,
  ) {
    order = {
      seller: seller,
      buyer: buyer,
      maker: maker,
      collection: collection,
      tokenId: tokenId,
      price: price,
      expiry: expiry,
      nonce: nonce,
      state: state,
    };

    return order;
  }

  describe('VLXNFT Transer', function () {
    it('Should not set receiver to Zero address or creator address', async function () {
      await expect(ENft.transferToken(nftmint.address, ethers.constants.AddressZero, NEW_TOKEN_ID)).to.be.revertedWith(
        'Wrong receiver',
      );
      console.log('transfer');
      await expect(ENft.transferToken(nftmint.address, ENft.address, NEW_TOKEN_ID)).to.be.revertedWith(
        'Wrong receiver',
      );

      await ENft.transferToken(nftmint.address, account1.address, NEW_TOKEN_ID);
    });

    it('Should change into new owner after transferring', async function () {
      await ENft.transferToken(nftmint.address, account1.address, NEW_TOKEN_ID);
      const newOwner = await nftmint.ownerOf(NEW_TOKEN_ID);
      expect(newOwner).to.equal(account1.address);
    });

    it('Should transfer tokens between accounts', async function () {
      const initialBalance = await nftmint.balanceOf(account1.address);
      expect(initialBalance).to.equal(0);

      await ENft.transferToken(nftmint.address, account1.address, NEW_TOKEN_ID);
      const addr1Balance = await nftmint.balanceOf(account1.address);
      expect(addr1Balance).to.equal(1);
    });

    it('Should fail if sender doesn’t have enough tokens', async function () {
      const initialOwnerBalance = await nftmint.balanceOf(account.address);
      await expect(ENft.connect(account1).transferToken(nftmint.address, account.address, 1)).to.be.reverted;
      expect(await nftmint.balanceOf(account.address)).to.equal(initialOwnerBalance);
    });

    it('Should exist collection for transferring', async function () {
      await expect(ENft.connect(account1).transferToken(nftmint.address, account2.address, 1)).to.be.revertedWith(
        'Only Token Owner can transfer token',
      );
    });

    it('Should not be zero address or this contract for receiver', async function () {
      await expect(ENft.transferToken(nftmint.address, ethers.constants.AddressZero, 1)).to.be.revertedWith(
        'Wrong receiver',
      );
      await expect(ENft.transferToken(nftmint.address, ENft.address, 1)).to.be.revertedWith('Wrong receiver');
    });
  });

  describe('VLXNFT Buy', function () {
    it('Should be set state to zero', async () => {
      await setOrder(
        account1.address,
        account2.address,
        account3.address,
        nftmint.address,
        NEW_TOKEN_ID,
        price,
        expiry,
        nonce,
        1,
      );

      // let abi = ['function verifyHash(bytes32, uint8, bytes32, bytes32) public pure returns (address)'];

      // let provider = ethers.getDefaultProvider('ropsten');
      // let contractAddress = '0x80F85dA065115F576F1fbe5E14285dA51ea39260';
      // let contract = new ethers.Contract(contractAddress, abi, provider);

      let messageHash = ethers.utils.id('VLXSIGNMESSAGE');
      let messageHashBytes = ethers.utils.arrayify(messageHash);
      let flatSig = await wallet.signMessage(messageHashBytes);
      let message = JSON.stringify(order);

      // let sig = ethers.utils.splitSignature(flatSig);
      // let recovered = await contract.verifyHash(messageHash, sig.v, sig.r, sig.s);
      await expect(
        ENft.buyToken(order, flatSig, message, {
          value: price,
        }),
      ).to.be.revertedWith('Unfillable State');
    });

    it('Should be different seller and buyer.', async () => {
      await setOrder(
        account1.address,
        account1.address,
        account1.address,
        nftmint.address,
        NEW_TOKEN_ID,
        price,
        expiry,
        nonce,
        0,
      );

      let message = JSON.stringify(order);
      await expect(
        ENft.buyToken(order, flatSig, message, {
          value: price,
        }),
      ).to.be.revertedWith('Seller can not buy');
    });

    it('Should be right buyer.', async () => {
      await setOrder(
        account1.address,
        account2.address,
        account.address,
        nftmint.address,
        NEW_TOKEN_ID,
        price,
        expiry,
        nonce,
        0,
      );

      let message = JSON.stringify(order);
      await expect(
        ENft.buyToken(order, flatSig, message, {
          value: price,
        }),
      ).to.be.revertedWith('Wrong Buyer');
    });

    it('Should be right maker.', async () => {
      await setOrder(
        account1.address,
        account.address,
        account2.address,
        nftmint.address,
        NEW_TOKEN_ID,
        price,
        expiry,
        nonce,
        0,
      );

      let message = JSON.stringify(order);
      await expect(
        ENft.buyToken(order, flatSig, message, {
          value: price,
        }),
      ).to.be.revertedWith('Wrong Maker');
    });

    it('Should be sent price more than zero or token value.', async () => {
      await setOrder(
        account1.address,
        account.address,
        account2.address,
        nftmint.address,
        NEW_TOKEN_ID,
        price,
        expiry,
        nonce,
        0,
      );

      let message = JSON.stringify(order);
      await expect(
        ENft.buyToken(order, flatSig, message, {
          value: 0,
        }),
      ).to.be.revertedWith('Wrong Maker');
      await expect(
        ENft.buyToken(order, flatSig, message, {
          value: lowerPrice,
        }),
      ).to.be.revertedWith('Wrong Maker');
    });

    xit("Should be changed account's balance after buying", async () => {
      const initialBalance = await provider.getBalance(account.address);

      await ENft.connect(account1).buyToken(nftmint.address, NEW_TOKEN_ID, account.address, {
        value: price.toString(),
      });

      const finalBalance = await provider.getBalance(account.address);
      expect(ethers.utils.formatEther(initialBalance)).to.be.not.equal(ethers.utils.formatEther(finalBalance));
    });

    xit('Should be received royalty after buying', async () => {
      const initialBalance = await provider.getBalance(account.address);

      await ENft.connect(account1).buyToken(nftmint.address, NEW_TOKEN_ID, account.address, {
        value: price.toString(),
      });
      const finalBalance = await provider.getBalance(account.address);
      // expect(finalBalance.sub(initialBalance).toString()).to.equal((price * 0.9725).toString());
    });
  });

  xdescribe('VLXNFT SELL', function () {
    it('Should be sold by only owner', async () => {
      await expect(
        ENft.connect(account2).sellToken(nftmint.address, account1.address, NEW_TOKEN_ID, price.toString()),
      ).to.be.revertedWith('Only Token Owner can sell token');
    });
  });
});
