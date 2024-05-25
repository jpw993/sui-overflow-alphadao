## SuiFund


**SuiFund is a POC project for coin investment management on the Sui blockchain**



## Short Description
This project contains a Move smart contract for creating, participating in, and managing an on-chain coin investment management fund. The fund smart contract securely holds the SUI coins from investors and allows traders to trade uses coins on the Cetus DEX. 

## Intro Media
Demo: https://www.youtube.com/watch?v=Zk9pm4pE17Q
Pitch video: https://www.youtube.com/watch?v=gjM2OoldBxE
Pitch slides: https://www.canva.com/design/DAGFCZBrE08/xbVdEP4-rMhIdkTQkb6erw/view



## Full Description
The objective of asset management firms is to provide returns on cash deposited by investors. The investors benefit from the returns, which aim to beat keeping your money in a deposit account, and the asset managers benefit from a performance-based commission for providing this service.


In TradFi this operates on a model of trust; investors trust that the asset managers do not run away with their cash, that the cash is only traded in certain assets, and that defined risk limits are not breached.


SuiFund is a protocol that allows groups of traders (called "asset managers" in TradFi) to setup their organisations on-chain via a DAO (decentralised autonomous organization). This provides the following advantages:
- Security: tokens are locked in smart contracts, and transfer logic is pre-defined.
- Openness: anyone can be an asset manager or investor.
- Accountability: all trade transactions are recorded and visible on-chain.
- Voting rights: members can cast votes for actions such as removing a trader.


Additionally, the SuiFund project aims to bring the best practices from TradFi asset management to DeFi, including:
- Diversified teams with capital allocations
- Risk limits
- Coin restrictions
- Lock-in and notice periods 


## Technical Details
The Cetus clmm interface is not yes complete(they allow provide the function defination).
Therefor when deploying this smart contract the following arguments need to be supplied:
```
--skip-dependency-verification
```
