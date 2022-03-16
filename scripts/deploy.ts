import {ethers} from 'hardhat';

async function main() {
  const [account] = await ethers.getSigners();

  const ExchangeNft = await ethers.getContractFactory('ExchangeNFT');
  const ENft = await ExchangeNft.deploy(
    '0xc579D1f3CF86749E05CD06f7ADe17856c2CE3126',
    '0xBb9B6647C47bE7DC22eaDC4B412FE97FB881cF49',
    '0x33B07d9F412Aafd0D40861cbD3983df02F2882B9',
  );

  await ENft.deployed();

  console.log('Exchange deployed to:', ENft.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
