# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
```


## Impermanent Loss
Impermanent loss for liquidity providers is the change in dollar terms of their total stake in a given pool versus just holding the assets.

suppose WETH price = $3000
suppose DAI price = $1

alise create a pool of DAI/WETH pool by putting 10 WETH, 30000 DAI token, in total heaving value $60,000(To make it simple, we will not take the transaction fees into consideration)
now Alise become liquidity provider
now suppose WETH price goes upto $4,687.this will create a huge arbitrage opportunity, so immediately, an arbitrageur will buy ETH in Alice’s pool until the price is at par with the outside market.

so, after some arbitrage, alise pool will look like below (we are not considering tx fee)

DAI = 37,500, ETH =8
total amout of usd = $75,000((8ETH * $4,687.5) + 37,500))
if she had hold these token externally
value would be = 10*4.687.5+ 30000;
               =  $76,875
impermanent loos = 76875 -75000 =1,875               




