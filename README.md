### Kombat

- The onlyOwner modifier on each function serves as a point to sign and send transactions on the front-end on behalf of the user

- also permit2 should be used to transfer the gas from the user before the transaction is ran, the eth to run the transaction should be calculated and deducted from the user's usdc balance with permit2 . (i.e user is paying the transaction in usdc and not native eth)
- the owner would send transactions for the users after users sigm transaction from the front-end , thats simply the flow
- I would try implementing creating bets to understand this flow better
